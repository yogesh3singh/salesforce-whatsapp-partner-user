/**
 * @description WhatsApp controller for Partner Community users.
 *
 * ARCHITECTURE DECISION
 * ─────────────────────
 * Partner users cannot call OneXtel.WhatsAppService from non-Aura 
 * contexts (triggers, schedulers, queueables all fail with 
 * AuraHandledException). Solution: call directly from @AuraEnabled 
 * context combined with sharing rules on OneXtel objects that give 
 * partner users read access to Provider and Template records.
 *
 * SHARING RULES REQUIRED (Setup → Sharing Settings)
 * ──────────────────────────────────────────────────
 * WhatsApp Provider → Partner Users Group → Read
 * WhatsApp Template → Partner Users Group → Read  
 * WhatsApp Report   → Partner Users Group → Read/Write
 *
 * UNIVERSITY FILTER (same logic as WhatsAppChatController)
 * ─────────────────────────────────────────────────────────
 * Post Nov 2025:
 *   NMIMS      → provider name contains 'NMIMS'
 *   Symbiosis  → provider name contains 'Symbiosis'
 *   Others     → provider NOT NMIMS AND NOT Symbiosis
 * Pre Nov 2025:
 *   Provider name contains Lead_Vendor_source1__c value
 */
public without sharing class WACommunityController {

    private static final String NMIMS_KEY           = 'NMIMS';
    private static final String SYMBIOSIS_KEY       = 'Symbiosis';
    private static final Date   PRE_NOV_2025_CUTOFF = Date.newInstance(2025, 11, 1);
    private static final String NO_CONTENT_LABEL    = '(No content)';

    // ─────────────────────────────────────────────────────────────────────
    // getChatHistory
    // ─────────────────────────────────────────────────────────────────────
    /**
     * @description Retrieves WhatsApp chat history for a Lead Opportunity.
     * @param leadOpportunityId The Id of the Lead Opportunity record.
     * @return List of WAMessageWrapper objects.
     */
    @AuraEnabled(cacheable=true)
    public static List<WAMessageWrapper> getChatHistory(Id leadOpportunityId) {
        List<Lead_Opportunity__c> loList = [
            SELECT Id, Name, OwnerId, Phone__c, 
                   Lead_Vendor_source1__c, CreatedDate
            FROM   Lead_Opportunity__c
            WHERE  Id = :leadOpportunityId
            LIMIT  1
        ];

        if (loList.isEmpty()) {
            throw new AuraHandledException(
                'Lead Opportunity not found.'
            );
        }

        Lead_Opportunity__c leadOpp = loList[0];

        if (String.isBlank(leadOpp.Phone__c)) {
            return new List<WAMessageWrapper>();
        }

        String likePattern  = buildPhoneLikePattern(leadOpp.Phone__c);
        UniversityContext uc = buildUniversityContext(leadOpp);

        List<OneXtel__WhatsApp_DLR__c> allMessages = [
            SELECT Id,
                   OneXtel__Status__c,
                   OneXtel__Type__c,
                   OneXtel__Message_Content__c,
                   OneXtel__From_Number__c,
                   OneXtel__Contact_Phone__c,
                   OneXtel__User_Name__c,
                   OneXtel__Provider__r.Name,
                   OneXtel__Template__r.Name,
                   OneXtel__Variables__c,
                   OneXtel__Error__c,
                   OneXtel__Media_Type__c,
                   OneXtel__Mime_Type__c,
                   OneXtel__Json__c,
                   CreatedDate,
                   Owner.Name
            FROM   OneXtel__WhatsApp_DLR__c
            WHERE  OneXtel__From_Number__c   LIKE :likePattern
            OR     OneXtel__Contact_Phone__c LIKE :likePattern
            ORDER  BY CreatedDate ASC
            LIMIT  1000
        ];

        return buildWrappers(allMessages, uc);
    }

    // ─────────────────────────────────────────────────────────────────────
    // getLeadInfo
    // ─────────────────────────────────────────────────────────────────────
    /**
     * @description Returns Lead Opportunity info for the chat header.
     * @param leadOpportunityId The Id of the Lead Opportunity record.
     * @return WALeadInfo wrapper.
     */
    @AuraEnabled(cacheable=true)
    public static WALeadInfo getLeadInfo(Id leadOpportunityId) {
        List<Lead_Opportunity__c> loList = [
            SELECT Id, Name, OwnerId, Owner.Name, 
                   Phone__c, Lead_Vendor_source1__c
            FROM   Lead_Opportunity__c
            WHERE  Id = :leadOpportunityId
            LIMIT  1
        ];

        if (loList.isEmpty()) {
            throw new AuraHandledException(
                'Lead Opportunity not found.'
            );
        }

        Lead_Opportunity__c lo = loList[0];
        WALeadInfo info        = new WALeadInfo();
        info.id                = lo.Id;
        info.name              = lo.Name;
        info.ownerName         = lo.Owner.Name;
        info.phone             = lo.Phone__c;
        info.university        = lo.Lead_Vendor_source1__c;
        info.isCurrentUserOwner = (lo.OwnerId == UserInfo.getUserId());
        return info;
    }

    // ─────────────────────────────────────────────────────────────────────
    // getProviders
    // ─────────────────────────────────────────────────────────────────────
    /**
     * @description Returns available WhatsApp providers.
     * Partner users can see these via sharing rules.
     * @return List of WAProviderOption wrappers.
     */
    @AuraEnabled(cacheable=true)
    public static List<WAProviderOption> getProviders() {
        List<WAProviderOption> options = new List<WAProviderOption>();
        for (OneXtel__WhatsApp_Provider__c p : [
            SELECT Id, Name
            FROM   OneXtel__WhatsApp_Provider__c
            ORDER  BY Name ASC
            LIMIT  50
        ]) {
            WAProviderOption opt = new WAProviderOption();
            opt.id    = p.Id;
            opt.label = p.Name;
            opt.value = p.Id;
            options.add(opt);
        }
        return options;
    }

    // ─────────────────────────────────────────────────────────────────────
    // getTemplates
    // ─────────────────────────────────────────────────────────────────────
    /**
     * @description Returns WhatsApp templates matching search term.
     * Partner users can see these via sharing rules.
     * @param searchTerm Optional filter string.
     * @return List of WATemplateOption wrappers.
     */
    @AuraEnabled(cacheable=true)
    public static List<WATemplateOption> getTemplates(String searchTerm) {
        List<WATemplateOption> options = new List<WATemplateOption>();
        String likeClause = String.isBlank(searchTerm)
            ? '%'
            : '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';

        for (OneXtel__WhatsApp_Template__c t : [
            SELECT Id, Name
            FROM   OneXtel__WhatsApp_Template__c
            WHERE  Name LIKE :likeClause
            ORDER  BY Name ASC
            LIMIT  50
        ]) {
            WATemplateOption opt = new WATemplateOption();
            opt.id    = t.Id;
            opt.label = t.Name;
            opt.value = t.Id;
            options.add(opt);
        }
        return options;
    }

    // ─────────────────────────────────────────────────────────────────────
    // sendTemplate
    // ─────────────────────────────────────────────────────────────────────
    /**
     * @description Sends a WhatsApp template message.
     * Called from @AuraEnabled context — OneXtel validates this.
     * Partner sharing rules ensure provider/template records are visible.
     * @param recordId    Lead Opportunity Id.
     * @param templateId  OneXtel template record Id.
     * @param phone       Destination phone number.
     * @param providerId  OneXtel provider record Id.
     * @return WASendResult with success flag and message.
     */
    @AuraEnabled
    public static WASendResult sendTemplate(
        Id recordId, Id templateId, String phone, Id providerId
    ) {
        WASendResult result = new WASendResult();
        try {
            OneXtel.CustomResponse resp =
                OneXtel.WhatsAppService.sendMessage(
                    recordId, templateId, 'Phone__c', phone
                );
            result.success = evaluateResponse(resp);
            result.message = resp != null ? resp.message : 'No response.';
        } catch (Exception ex) {
            result.success = false;
            result.message = ex.getMessage();
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────
    // sendFreeform
    // ─────────────────────────────────────────────────────────────────────
    /**
     * @description Sends a freeform WhatsApp message.
     * Called from @AuraEnabled context — OneXtel validates this.
     * @param recordId    Lead Opportunity Id.
     * @param phone       Destination phone number.
     * @param messageBody Text body.
     * @param mediaType   Media type or null.
     * @param mediaUrl    Media URL or null.
     * @param fileName    File name or null.
     * @param objectName  Salesforce object API name.
     * @param providerId  OneXtel provider record Id.
     * @return WASendResult with success flag and message.
     */
    @AuraEnabled
    public static WASendResult sendFreeform(
        Id     recordId,
        String phone,
        String messageBody,
        String mediaType,
        String mediaUrl,
        String fileName,
        String objectName,
        Id     providerId
    ) {
        WASendResult result = new WASendResult();
        try {
            OneXtel.CustomResponse resp =
                OneXtel.WhatsAppService.sendFreeformMessage(
                    objectName, recordId, providerId,
                    phone, messageBody, mediaType, mediaUrl, fileName
                );
            result.success = evaluateResponse(resp);
            result.message = resp != null ? resp.message : 'No response.';
        } catch (Exception ex) {
            result.success = false;
            result.message = ex.getMessage();
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────
    private static Boolean evaluateResponse(OneXtel.CustomResponse resp) {
        if (resp == null || resp.message == null) return false;
        String msg = resp.message.toLowerCase();
        return !msg.contains('fail') && !msg.contains('error');
    }

    private static String buildPhoneLikePattern(String phone) {
        String digits = phone.replaceAll('[^0-9]', '');
        String last10 = digits.length() >= 10
                        ? digits.substring(digits.length() - 10) : digits;
        return '%' + last10;
    }

    private static UniversityContext buildUniversityContext(
        Lead_Opportunity__c lo
    ) {
        UniversityContext uc = new UniversityContext();
        uc.university   = String.isBlank(lo.Lead_Vendor_source1__c)
                          ? '' : lo.Lead_Vendor_source1__c.trim();
        uc.isPreNov2025 = lo.CreatedDate.date() < PRE_NOV_2025_CUTOFF;
        uc.isNMIMS      = uc.university.equalsIgnoreCase(NMIMS_KEY);
        uc.isSymbiosis  = uc.university.equalsIgnoreCase(SYMBIOSIS_KEY);
        return uc;
    }

    private static Boolean shouldInclude(
        String providerName, UniversityContext uc
    ) {
        String pLower = providerName.toLowerCase();
        if (uc.isPreNov2025) {
            return !String.isBlank(uc.university)
                   && pLower.contains(uc.university.toLowerCase());
        }
        if (uc.isNMIMS)     return pLower.contains(NMIMS_KEY.toLowerCase());
        if (uc.isSymbiosis) return pLower.contains(SYMBIOSIS_KEY.toLowerCase());
        return !pLower.contains(NMIMS_KEY.toLowerCase())
            && !pLower.contains(SYMBIOSIS_KEY.toLowerCase());
    }

    private static List<WAMessageWrapper> buildWrappers(
        List<OneXtel__WhatsApp_DLR__c> records, UniversityContext uc
    ) {
        List<WAMessageWrapper> result = new List<WAMessageWrapper>();
        for (OneXtel__WhatsApp_DLR__c msg : records) {
            String providerName = (msg.OneXtel__Provider__r != null
                && msg.OneXtel__Provider__r.Name != null)
                ? msg.OneXtel__Provider__r.Name : '';

            if (!shouldInclude(providerName, uc)) continue;

            String templateName = msg.OneXtel__Template__r != null
                ? msg.OneXtel__Template__r.Name : null;

            WAMessageWrapper w  = new WAMessageWrapper();
            w.id                = msg.Id;
            w.status            = msg.OneXtel__Status__c;
            w.content           = extractContent(msg, templateName);
            w.fromNumber        = msg.OneXtel__From_Number__c;
            w.toNumber          = msg.OneXtel__Contact_Phone__c;
            w.userName          = msg.OneXtel__User_Name__c;
            w.providerName      = providerName;
            w.templateName      = templateName;
            w.error             = msg.OneXtel__Error__c;
            w.mediaType         = msg.OneXtel__Media_Type__c;
            w.createdDate       = msg.CreatedDate;
            w.ownerName         = msg.Owner.Name;
            w.isInbound         = msg.OneXtel__Status__c != null
                && msg.OneXtel__Status__c.toLowerCase() == 'inbound';
            result.add(w);
        }
        return result;
    }

    private static String extractContent(
        OneXtel__WhatsApp_DLR__c msg, String templateName
    ) {
        if (!String.isBlank(msg.OneXtel__Message_Content__c)) {
            return msg.OneXtel__Message_Content__c;
        }
        if (!String.isBlank(msg.OneXtel__Json__c)) {
            try {
                Map<String, Object> m =
                    (Map<String, Object>) JSON.deserializeUntyped(
                        msg.OneXtel__Json__c);
                if (m.containsKey('text') && m.get('text') != null) {
                    String txt = String.valueOf(m.get('text')).trim();
                    if (!String.isBlank(txt)) return txt;
                }
            } catch (Exception e) { }
        }
        if (!String.isBlank(msg.OneXtel__Variables__c)) {
            try {
                Map<String, Object> m =
                    (Map<String, Object>) JSON.deserializeUntyped(
                        msg.OneXtel__Variables__c);
                if (m.containsKey('bodyText') && m.get('bodyText') != null) {
                    String bt = String.valueOf(m.get('bodyText')).trim();
                    if (!String.isBlank(bt)) return bt;
                }
            } catch (Exception e) { }
        }
        if (!String.isBlank(templateName)) {
            return '📋 Template: ' + templateName;
        }
        return NO_CONTENT_LABEL;
    }

    // ─────────────────────────────────────────────────────────────────────
    // INNER CLASSES
    // ─────────────────────────────────────────────────────────────────────
    private class UniversityContext {
        String  university;
        Boolean isPreNov2025;
        Boolean isNMIMS;
        Boolean isSymbiosis;
    }

    public class WAMessageWrapper {
        @AuraEnabled public String   id;
        @AuraEnabled public String   status;
        @AuraEnabled public String   content;
        @AuraEnabled public String   fromNumber;
        @AuraEnabled public String   toNumber;
        @AuraEnabled public String   userName;
        @AuraEnabled public String   providerName;
        @AuraEnabled public String   templateName;
        @AuraEnabled public String   error;
        @AuraEnabled public String   mediaType;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String   ownerName;
        @AuraEnabled public Boolean  isInbound;
    }

    public class WALeadInfo {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public String  phone;
        @AuraEnabled public String  university;
        @AuraEnabled public Boolean isCurrentUserOwner;
    }

    public class WAProviderOption {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class WATemplateOption {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class WASendResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
    }
}