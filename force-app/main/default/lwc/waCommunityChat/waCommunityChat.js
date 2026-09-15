import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent }  from 'lightning/platformShowToastEvent';
import { refreshApex }     from '@salesforce/apex';
import getChatHistory  from '@salesforce/apex/WACommunityController.getChatHistory';
import getLeadInfo     from '@salesforce/apex/WACommunityController.getLeadInfo';
import getTemplates    from '@salesforce/apex/WACommunityController.getTemplates';
import getProviders    from '@salesforce/apex/WACommunityController.getProviders';
import sendTemplate    from '@salesforce/apex/WACommunityController.sendTemplate';
import sendFreeform    from '@salesforce/apex/WACommunityController.sendFreeform';

const OBJECT_NAME       = 'Lead_Opportunity__c';
const WINDOW_HOURS      = 24;
const TEMPLATE_DEBOUNCE = 300;
const POLLING_MS        = 8000;
const NMIMS_KEY         = 'nmims';
const SYMBIOSIS_KEY     = 'symbiosis';

export default class WaCommunityChat extends LightningElement {

    // ── Public ───────────────────────────────────────────────────────────
    @api recordId;

    // ── Chat State ───────────────────────────────────────────────────────
    @track messages      = [];
    @track leadInfo      = {};
    @track isLoading     = true;
    @track accessDenied  = false;
    @track searchTerm    = '';
    @track activeFilter  = 'all';

    // ── Send Panel ───────────────────────────────────────────────────────
    @track sendMode             = 'template';
    @track isSending            = false;
    @track selectedProviderId   = '';
    @track selectedProviderLabel = '';
    @track providerOptions      = [];
    @track templateOptions      = [];
    @track templateSearchTerm   = '';
    @track isTemplatesLoading   = false;
    @track showTemplateDropdown = false;
    @track selectedTemplateId   = '';
    @track selectedTemplateName = '';
    @track selectedMediaType    = 'Text';
    @track freeformMessage      = '';
    @track mediaUrl             = '';
    @track mediaFileName        = '';

    // ── Private ──────────────────────────────────────────────────────────
    _wiredMessagesResult;
    _wiredLeadInfoResult;
    _templateDebounceTimer;
    _pollingInterval     = null;
    _lastMessageCount    = 0;

    // ── Lifecycle ────────────────────────────────────────────────────────
    connectedCallback() {
        console.log('waCommunityChat recordId from @api:', this.recordId);

        if (!this.recordId) {
            // Extract recordId from community URL
            // URL pattern: /s/lead-opportunity/{recordId}/{slug}
            const urlParts  = window.location.pathname.split('/');
            const loIndex   = urlParts.indexOf('lead-opportunity');
            if (loIndex !== -1 && urlParts[loIndex + 1]) {
                this.recordId = urlParts[loIndex + 1];
                console.log('recordId from URL:', this.recordId);
            } else {
                // Fallback — find 15/18 char alphanumeric segment
                const match = urlParts.find(p =>
                    (p.length === 18 || p.length === 15) &&
                    /^[a-zA-Z0-9]+$/.test(p)
                );
                if (match) {
                    this.recordId = match;
                    console.log('recordId from URL fallback:', this.recordId);
                } else {
                    this.isLoading    = false;
                    this.accessDenied = true;
                    console.error('recordId could not be determined');
                }
            }
        }
    }

    disconnectedCallback() {
        this.stopPolling();
    }

    // ── Wire: Lead Info ──────────────────────────────────────────────────
    @wire(getLeadInfo, { leadOpportunityId: '$recordId' })
    wiredLeadInfo(result) {
        this._wiredLeadInfoResult = result;
        if (!this.recordId) {
            this.isLoading    = false;
            this.accessDenied = true;
            return;
        }
        if (result.data) {
            this.leadInfo           = result.data;
            this.selectedProviderId = '';
            this._loadProviders();
        } else if (result.error) {
            const msg = result.error?.body?.message || '';
            if (msg.includes('not found') || msg.includes('Insufficient')) {
                this.accessDenied = true;
                this.isLoading    = false;
            } else {
                this.handleError(result.error);
            }
        }
    }

    // ── Wire: Chat Messages ──────────────────────────────────────────────
    @wire(getChatHistory, { leadOpportunityId: '$recordId' })
    wiredMessages(result) {
        this._wiredMessagesResult = result;
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        if (result.data) {
            this.messages          = result.data;
            this._lastMessageCount = result.data.length;
            this.isLoading         = false;
            this.accessDenied      = false;
            this.scrollToBottom();
            this.startPolling();
        } else if (result.error) {
            const msg = result.error?.body?.message || '';
            if (msg.includes('not found') || msg.includes('Insufficient')) {
                this.accessDenied = true;
            } else {
                this.handleError(result.error);
            }
            this.isLoading = false;
        }
    }

    // ── Load Providers ───────────────────────────────────────────────────
    _loadProviders() {
        getProviders()
            .then(data => { this.providerOptions = data || []; })
            .catch(() => { this.providerOptions = []; });
    }

    // ── Visibility ───────────────────────────────────────────────────────
    get showChat()   { return !this.isLoading && !this.accessDenied; }
    get noMessages() { return this.filteredMessages.length === 0; }

    // ── Header ───────────────────────────────────────────────────────────
    get leadInitials() {
        const name = this.leadInfo?.name || '';
        return name.split(' ')
            .slice(0, 2)
            .map(n => n.charAt(0).toUpperCase())
            .join('') || 'LO';
    }

    get universityLabel() {
        return this.leadInfo?.university || '';
    }

    get maskedPhone() {
        const phone = this.leadInfo?.phone || '';
        if (!phone) return '';
        return phone.length > 4
            ? '******' + phone.slice(-4)
            : '****';
    }

    // ── Provider Filter ──────────────────────────────────────────────────
    get filteredProviderOptions() {
        const university = (this.leadInfo?.university || '').toLowerCase().trim();
        const isSymbiosis = university === SYMBIOSIS_KEY;

        return this.providerOptions.filter(p => {
            const pName = (p.label || '').toLowerCase();
            const isSymbiosisProvider = pName.includes(SYMBIOSIS_KEY);
            if (isSymbiosis) return isSymbiosisProvider;
            return !isSymbiosisProvider;
        });
    }

    // ── 24h Window ───────────────────────────────────────────────────────
    get lastInboundDate() {
        const inbound = this.messages
            .filter(m => m.isInbound)
            .map(m => new Date(m.createdDate));
        return inbound.length ? new Date(Math.max(...inbound)) : null;
    }

    get isWindowActive() {
        const last = this.lastInboundDate;
        if (!last) return false;
        return (Date.now() - last.getTime()) / 3600000 < WINDOW_HOURS;
    }

    get windowStatus() {
        const last = this.lastInboundDate;
        if (!last) return '—';
        if (!this.isWindowActive) return 'Closed';
        const msLeft   = (last.getTime() + WINDOW_HOURS * 3600000) - Date.now();
        const hrsLeft  = Math.floor(msLeft / 3600000);
        const minsLeft = Math.floor((msLeft % 3600000) / 60000);
        return hrsLeft > 0 ? `${hrsLeft}h ${minsLeft}m` : `${minsLeft}m`;
    }

    // ── Stats ────────────────────────────────────────────────────────────
    get totalMessages()  { return this.messages.length; }
    get inboundCount()   { return this.messages.filter(m => m.isInbound).length; }
    get outboundCount()  { return this.messages.filter(m => !m.isInbound).length; }

    // ── Filter Variants ──────────────────────────────────────────────────
    get allBtnVariant()      { return this.activeFilter === 'all'      ? 'brand' : 'neutral'; }
    get inboundBtnVariant()  { return this.activeFilter === 'inbound'  ? 'brand' : 'neutral'; }
    get outboundBtnVariant() { return this.activeFilter === 'outbound' ? 'brand' : 'neutral'; }

    // ── Filtered Messages ─────────────────────────────────────────────────
    get filteredMessages() {
        let msgs = [...this.messages];
        if (this.activeFilter === 'inbound')       msgs = msgs.filter(m => m.isInbound);
        else if (this.activeFilter === 'outbound') msgs = msgs.filter(m => !m.isInbound);
        if (this.searchTerm.trim()) {
            const term = this.searchTerm.toLowerCase();
            msgs = msgs.filter(m =>
                (m.content      || '').toLowerCase().includes(term) ||
                (m.userName     || '').toLowerCase().includes(term) ||
                (m.templateName || '').toLowerCase().includes(term) ||
                (m.providerName || '').toLowerCase().includes(term)
            );
        }
        return msgs;
    }

    // ── Grouped Messages ─────────────────────────────────────────────────
    get groupedMessages() {
        const groups = {};
        this.filteredMessages.forEach(msg => {
            const rawDate  = new Date(msg.createdDate);
            const dateKey  = this.formatDate(rawDate);
            const enriched = {
                ...msg,
                formattedTime : this.formatTime(rawDate),
                statusIcon    : this.getStatusIcon(msg.status),
                statusClass   : this.getStatusClass(msg.status),
                bubbleClass   : 'msg-row ' + (msg.isInbound ? 'msg-row--in' : 'msg-row--out'),
                innerClass    : 'bubble '  + (msg.isInbound ? 'bubble--in'  : 'bubble--out'),
                showTemplate  : !msg.isInbound && !!msg.templateName
            };
            if (!groups[dateKey]) groups[dateKey] = { date: dateKey, messages: [] };
            groups[dateKey].messages.push(enriched);
        });
        return Object.values(groups);
    }

    // ── Send Panel Getters ───────────────────────────────────────────────
    get isTemplateMode()     { return this.sendMode === 'template'; }
    get isFreeformMode()     { return this.sendMode === 'freeform'; }
    get freeformDisabled()   { return !this.isWindowActive; }
    get hasTemplateResults() { return this.templateOptions.length > 0; }
    get showMediaUrl()       { return this.selectedMediaType !== 'Text'; }

    get templateTabClass() {
        return 'send-tab' + (this.sendMode === 'template' ? ' tab--active' : '');
    }
    get freeformTabClass() {
        return 'send-tab' + (this.sendMode === 'freeform' ? ' tab--active' : '');
    }

    get sendTemplateDisabled() {
        return !this.selectedTemplateId || !this.selectedProviderId || this.isSending;
    }
    get sendFreeformDisabled() {
        const hasContent = this.selectedMediaType === 'Text'
            ? this.freeformMessage.trim().length > 0
            : this.mediaUrl.trim().length > 0;
        return !this.selectedProviderId || !hasContent || this.isSending;
    }

    // ── Chat Handlers ────────────────────────────────────────────────────
    handleFilter(event) { this.activeFilter = event.target.dataset.filter; }
    handleSearch(event) { this.searchTerm   = event.target.value; }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this._wiredMessagesResult).then(() => {
            this.isLoading = false;
            this.toast('Refreshed', 'Chat history is up to date.', 'success');
        });
    }

    // ── Send Panel Handlers ──────────────────────────────────────────────
    handleModeSwitch(event) {
        const mode = event.currentTarget.dataset.mode;
        if (mode === 'freeform' && !this.isWindowActive) return;
        this.sendMode             = mode;
        this.showTemplateDropdown = false;
    }

    handleProviderChange(event) {
        this.selectedProviderId    = event.target.value;
        const opts                 = event.target.options;
        const selected             = [...opts].find(o => o.value === event.target.value);
        this.selectedProviderLabel = selected ? selected.text : '';
    }

    handleMediaTypeChange(event)  { this.selectedMediaType  = event.target.value; }
    handleFreeformInput(event)    { this.freeformMessage    = event.target.value; }
    handleMediaUrlChange(event)   { this.mediaUrl           = event.target.value; }
    handleFileNameChange(event)   { this.mediaFileName      = event.target.value; }

    handleComposerKeydown(event) {
        if (event.key === 'Enter' && event.ctrlKey) {
            event.preventDefault();
            if (!this.sendFreeformDisabled) this.handleSendFreeform();
        }
    }

    // ── Template Search ──────────────────────────────────────────────────
    handleTemplateSearch(event) {
        this.templateSearchTerm   = event.target.value;
        this.showTemplateDropdown = true;
        clearTimeout(this._templateDebounceTimer);
        this._templateDebounceTimer = setTimeout(() => {
            this._fetchTemplates(this.templateSearchTerm);
        }, TEMPLATE_DEBOUNCE);
    }

    handleTemplateInputFocus() {
        this.showTemplateDropdown = true;
        if (!this.templateOptions.length) this._fetchTemplates('');
    }

    _fetchTemplates(term) {
        this.isTemplatesLoading = true;
        getTemplates({ searchTerm: term })
            .then(data => {
                this.templateOptions    = data || [];
                this.isTemplatesLoading = false;
            })
            .catch(() => {
                this.isTemplatesLoading = false;
                this.templateOptions    = [];
            });
    }

    handleTemplateSelect(event) {
        this.selectedTemplateId   = event.currentTarget.dataset.id;
        this.selectedTemplateName = event.currentTarget.dataset.label;
        this.showTemplateDropdown = false;
        this.templateSearchTerm   = '';
    }

    clearTemplate() {
        this.selectedTemplateId   = '';
        this.selectedTemplateName = '';
        this.templateSearchTerm   = '';
    }

    // ── Send Template ────────────────────────────────────────────────────
    handleSendTemplate() {
        if (this.sendTemplateDisabled) return;
        const phone = this.leadInfo?.phone;
        if (!phone) {
            this.toast('Missing phone',
                'No phone number on this Lead Opportunity.', 'warning');
            return;
        }
        this.isSending = true;
        sendTemplate({
            recordId   : this.recordId,
            templateId : this.selectedTemplateId,
            phone      : phone,
            providerId : this.selectedProviderId
        })
        .then(result => {
            this.isSending = false;
            if (result?.success) {
                this.toast('Message Sent',
                    'Template message sent successfully.', 'success');
                this.clearTemplate();
                this._refreshMessages();
            } else {
                this.toast('Send Failed',
                    result?.message || 'Unknown error.', 'error');
            }
        })
        .catch(err => {
            this.isSending = false;
            this.toast('Send Error',
                err?.body?.message || 'Unexpected error.', 'error');
        });
    }

    // ── Send Freeform ────────────────────────────────────────────────────
    handleSendFreeform() {
        if (this.sendFreeformDisabled) return;
        const phone = this.leadInfo?.phone;
        if (!phone) {
            this.toast('Missing phone',
                'No phone number on this Lead Opportunity.', 'warning');
            return;
        }
        this.isSending = true;
        sendFreeform({
            recordId    : this.recordId,
            phone       : phone,
            messageBody : this.freeformMessage,
            mediaType   : this.selectedMediaType !== 'Text'
                          ? this.selectedMediaType : null,
            mediaUrl    : this.mediaUrl     || null,
            fileName    : this.mediaFileName || null,
            objectName  : OBJECT_NAME,
            providerId  : this.selectedProviderId
        })
        .then(result => {
            this.isSending = false;
            if (result?.success) {
                this.toast('Message Sent',
                    'Message sent successfully.', 'success');
                this.freeformMessage = '';
                this.mediaUrl        = '';
                this.mediaFileName   = '';
                const ta = this.template.querySelector('.msg-composer');
                if (ta) ta.value = '';
                this._refreshMessages();
            } else {
                this.toast('Send Failed',
                    result?.message || 'Unknown error.', 'error');
            }
        })
        .catch(err => {
            this.isSending = false;
            this.toast('Send Error',
                err?.body?.message || 'Unexpected error.', 'error');
        });
    }

    // ── Auto Polling ─────────────────────────────────────────────────────
    startPolling() {
        this.stopPolling();
        this._pollingInterval = setInterval(() => {
            this._silentRefresh();
        }, POLLING_MS);
    }

    stopPolling() {
        if (this._pollingInterval) {
            clearInterval(this._pollingInterval);
            this._pollingInterval = null;
        }
    }

    _silentRefresh() {
        refreshApex(this._wiredMessagesResult).then(() => {
            const newCount = this.messages.length;
            if (newCount > this._lastMessageCount) {
                this._lastMessageCount = newCount;
                this.scrollToBottom();
                this._playNotificationSound();
            }
        });
    }

    _playNotificationSound() {
        try {
            const ctx        = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = ctx.createOscillator();
            const gainNode   = ctx.createGain();
            oscillator.connect(gainNode);
            gainNode.connect(ctx.destination);
            oscillator.type            = 'sine';
            oscillator.frequency.value = 520;
            gainNode.gain.setValueAtTime(0.3, ctx.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.4);
            oscillator.start(ctx.currentTime);
            oscillator.stop(ctx.currentTime + 0.4);
        } catch (e) { }
    }

    _refreshMessages() {
        setTimeout(() => {
            refreshApex(this._wiredMessagesResult).then(() => {
                this.scrollToBottom();
            });
        }, 1500);
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    handleError(error) {
        this.toast('Error loading chat',
            error?.body?.message || 'An unexpected error occurred.', 'error');
        this.isLoading = false;
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getStatusIcon(status) {
        if (!status) return '';
        const s = status.toLowerCase();
        if (s === 'read')                    return '✓✓';
        if (s === 'delivered')               return '✓✓';
        if (s === 'sent' || s === 'success') return '✓';
        if (s === 'failed' || s === 'error') return '⚠';
        return '';
    }

    getStatusClass(status) {
        if (!status) return 'status-sent';
        const s = status.toLowerCase();
        if (s === 'read')                    return 'status-read';
        if (s === 'delivered')               return 'status-delivered';
        if (s === 'failed' || s === 'error') return 'status-error';
        return 'status-sent';
    }

    formatDate(date) {
        const today     = new Date();
        const yesterday = new Date(today);
        yesterday.setDate(today.getDate() - 1);
        if (this.isSameDay(date, today))     return 'Today';
        if (this.isSameDay(date, yesterday)) return 'Yesterday';
        return date.toLocaleDateString('en-IN', {
            day: '2-digit', month: 'short', year: 'numeric'
        });
    }

    formatTime(date) {
        return date.toLocaleTimeString('en-IN', {
            hour: '2-digit', minute: '2-digit', hour12: true
        });
    }

    isSameDay(d1, d2) {
        return d1.getDate()     === d2.getDate()  &&
               d1.getMonth()    === d2.getMonth() &&
               d1.getFullYear() === d2.getFullYear();
    }

    scrollToBottom() {
        Promise.resolve().then(() => {
            const thread = this.refs?.thread;
            if (thread) thread.scrollTop = thread.scrollHeight;
        });
    }
}