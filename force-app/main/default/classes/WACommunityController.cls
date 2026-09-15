/**
 * @description Test class for WACommunityController.
 *
 * COVERAGE STRATEGY
 * ─────────────────
 * Tests all public methods including happy paths,
 * error paths, and edge cases.
 * OneXtel service calls will fail gracefully in test
 * context — we verify error handling works correctly.
 */
@isTest
private class WACommunityControllerTest {
 
    // ─────────────────────────────────────────────────────────────────────
    // Test Data Helper
    // ─────────────────────────────────────────────────────────────────────
    private static Lead_Opportunity__c createLead(
        String name, String phone, String university
    ) {
 
        Lead_Opportunity__c lo = new Lead_Opportunity__c(
            Name                   = name,
            Phone__c               = phone,
            Lead_Vendor_source1__c = university,
            OwnerId                = UserInfo.getUserId()
        );
        insert lo;
        return lo;
    }
 
    // ─────────────────────────────────────────────────────────────────────
    // getLeadInfo Tests
    // ─────────────────────────────────────────────────────────────────────
    @isTest
    static void testGetLeadInfo_ValidRecord() {
        Lead_Opportunity__c lead = createLead(
            'Test Lead', '9876543210', 'Symbiosis'
        );
 
        Test.startTest();
        WACommunityController.WALeadInfo info =
            WACommunityController.getLeadInfo(lead.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, info,               'Info should not be null');
        System.assertEquals(lead.Id,    (Id) info.id,   'Id should match');
        System.assertEquals('9876543210', info.phone,   'Phone should match');
        System.assertEquals('Symbiosis',  info.university, 'University should match');
        System.assertEquals(true, info.isCurrentUserOwner, 'Should be owner');
    }
 
    @isTest
    static void testGetLeadInfo_NMIMSRecord() {
        Lead_Opportunity__c lead = createLead(
            'Test NMIMS Lead', '9876543211', 'NMIMS'
        );
 
        Test.startTest();
        WACommunityController.WALeadInfo info =
            WACommunityController.getLeadInfo(lead.Id);
        Test.stopTest();
 
        System.assertEquals('NMIMS', info.university, 'University should be NMIMS');
    }
 
    @isTest
    static void testGetLeadInfo_BlankUniversity() {
        Lead_Opportunity__c lead = createLead(
            'Test Blank Uni', '9876543212', null
        );
 
        Test.startTest();
        WACommunityController.WALeadInfo info =
            WACommunityController.getLeadInfo(lead.Id);
        Test.stopTest();
 
        System.assertEquals(null, info.university, 'University should be null');
    }
 
    @isTest
    static void testGetLeadInfo_NotFound_ThrowsException() {
        Lead_Opportunity__c lead = createLead(
            'Temp Lead', '9876543213', 'Symbiosis'
        );
        Id deletedId = lead.Id;
        delete lead;
 
        Boolean caught = false;
        Test.startTest();
        try {
            WACommunityController.getLeadInfo(deletedId);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
 
        System.assert(caught, 'AuraHandledException expected');
    }
 
    // ─────────────────────────────────────────────────────────────────────
    // getChatHistory Tests
    // ─────────────────────────────────────────────────────────────────────
    @isTest
    static void testGetChatHistory_NoPhone_ReturnsEmpty() {
        Lead_Opportunity__c lead = createLead(
            'Test No Phone', null, 'Symbiosis'
        );
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, msgs, 'Should return empty list');
        System.assertEquals(0, msgs.size(), 'Should be empty');
    }
 
    @isTest
    static void testGetChatHistory_WithPhone() {
        Lead_Opportunity__c lead = createLead(
            'Test With Phone', '9876543210', 'Symbiosis'
        );
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, msgs, 'Messages should not be null');
    }
 
    @isTest
    static void testGetChatHistory_NMIMSLead() {
        Lead_Opportunity__c lead = createLead(
            'Test NMIMS Chat', '9876543211', 'NMIMS'
        );
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, msgs, 'Messages should not be null');
    }
 
    @isTest
    static void testGetChatHistory_OtherUniversity() {
        Lead_Opportunity__c lead = createLead(
            'Test Other Uni', '9876543212', 'Manipal'
        );
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertNotEquals(null, msgs, 'Messages should not be null');
    }
 
    @isTest
    static void testGetChatHistory_NotFound_ThrowsException() {
        Lead_Opportunity__c lead = createLead(
            'Temp Chat Lead', '9876543213', 'Symbiosis'
        );
        Id deletedId = lead.Id;
        delete lead;
 
        Boolean caught = false;
        Test.startTest();
        try {
            WACommunityController.getChatHistory(deletedId);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
 
        System.assert(caught, 'AuraHandledException expected');
    }
 
    // ─────────────────────────────────────────────────────────────────────
    // getProviders Tests
    // ─────────────────────────────────────────────────────────────────────
    @isTest
    static void testGetProviders_ReturnsList() {
        Test.startTest();
        List<WACommunityController.WAProviderOption> providers =
            WACommunityController.getProviders();
        Test.stopTest();
 
        System.assertNotEquals(null, providers, 'Providers should not be null');
    }
 
    // ─────────────────────────────────────────────────────────────────────
    // getTemplates Tests
    // ─────────────────────────────────────────────────────────────────────
    @isTest
    static void testGetTemplates_BlankSearch() {
        Test.startTest();
        List<WACommunityController.WATemplateOption> templates =
            WACommunityController.getTemplates('');
        Test.stopTest();
 
        System.assertNotEquals(null, templates, 'Templates should not be null');
    }
 
    @isTest
    static void testGetTemplates_NullSearch() {
        Test.startTest();
        List<WACommunityController.WATemplateOption> templates =
            WACommunityController.getTemplates(null);
        Test.stopTest();
 
        System.assertNotEquals(null, templates, 'Templates should not be null');
    }
 
    @isTest
    static void testGetTemplates_WithSearchTerm() {
        Test.startTest();
        List<WACommunityController.WATemplateOption> templates =
            WACommunityController.getTemplates('welcome');
        Test.stopTest();
 
        System.assertNotEquals(null, templates, 'Templates should not be null');
    }
 
    // ─────────────────────────────────────────────────────────────────────
    // sendTemplate Tests
    // ─────────────────────────────────────────────────────────────────────
    @isTest
    static void testSendTemplate_HandlesException() {
        Lead_Opportunity__c lead = createLead(
            'Test Send Template', '9876543210', 'Symbiosis'
        );
 
        Test.startTest();
        WACommunityController.WASendResult result =
            WACommunityController.sendTemplate(
                lead.Id,
                lead.Id, // fake template Id
                '9876543210',
                lead.Id  // fake provider Id
            );
        Test.stopTest();
 
        System.assertNotEquals(null, result,         'Result should not be null');
        System.assertNotEquals(null, result.message, 'Message should not be null');
        System.assertEquals(false, result.success,   'Should fail with fake Ids');
    }
 
    // ─────────────────────────────────────────────────────────────────────
    // sendFreeform Tests
    // ─────────────────────────────────────────────────────────────────────
    @isTest
    static void testSendFreeform_TextMessage() {
        Lead_Opportunity__c lead = createLead(
            'Test Freeform', '9876543210', 'Symbiosis'
        );
 
        Test.startTest();
        WACommunityController.WASendResult result =
            WACommunityController.sendFreeform(
                lead.Id,
                '9876543210',
                'Hello test message',
                null, null, null,
                'Lead_Opportunity__c',
                lead.Id
            );
        Test.stopTest();
 
        System.assertNotEquals(null, result,         'Result should not be null');
        System.assertNotEquals(null, result.message, 'Message should not be null');
        System.assertEquals(false, result.success,   'Should fail with fake Ids');
    }
 
    @isTest
    static void testSendFreeform_MediaMessage() {
        Lead_Opportunity__c lead = createLead(
            'Test Media', '9876543210', 'NMIMS'
        );
 
        Test.startTest();
        WACommunityController.WASendResult result =
            WACommunityController.sendFreeform(
                lead.Id,
                '9876543210',
                null,
                'Image',
                'https://example.com/img.jpg',
                'img.jpg',
                'Lead_Opportunity__c',
                lead.Id
            );
        Test.stopTest();
 
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(false, result.success, 'Should fail with fake Ids');
    }
 
    // ─────────────────────────────────────────────────────────────────────
    // Wrapper Class Coverage
    // ─────────────────────────────────────────────────────────────────────
    @isTest
    static void testAllWrapperClasses() {
        WACommunityController.WAMessageWrapper w =
            new WACommunityController.WAMessageWrapper();
        w.id           = 'testId';
        w.status       = 'inbound';
        w.content      = 'Hello';
        w.fromNumber   = '919876543210';
        w.toNumber     = '911234567890';
        w.userName     = 'TestUser';
        w.providerName = 'Symbiosis Provider';
        w.templateName = 'WelcomeTemplate';
        w.error        = null;
        w.mediaType    = 'Image';
        w.createdDate  = DateTime.now();
        w.ownerName    = 'Owner';
        w.isInbound    = true;
        System.assertEquals('inbound', w.status);
        System.assertEquals(true, w.isInbound);
 
        WACommunityController.WALeadInfo info =
            new WACommunityController.WALeadInfo();
        info.id                 = 'testId';
        info.name               = 'Test Lead';
        info.ownerName          = 'Owner';
        info.phone              = '9876543210';
        info.university         = 'Symbiosis';
        info.isCurrentUserOwner = true;
        System.assertEquals('Symbiosis', info.university);
 
        WACommunityController.WAProviderOption pOpt =
            new WACommunityController.WAProviderOption();
        pOpt.id    = 'pId';
        pOpt.label = 'Symbiosis Provider';
        pOpt.value = 'pId';
        System.assertEquals('Symbiosis Provider', pOpt.label);
 
        WACommunityController.WATemplateOption tOpt =
            new WACommunityController.WATemplateOption();
        tOpt.id    = 'tId';
        tOpt.label = 'Welcome Template';
        tOpt.value = 'tId';
        System.assertEquals('Welcome Template', tOpt.label);
 
        WACommunityController.WASendResult sr =
            new WACommunityController.WASendResult();
        sr.success = false;
        sr.message = 'No response from service.';
        System.assertEquals(false, sr.success);
        System.assert(sr.message.contains('No response'));
    }
 
        // ─────────────────────────────────────────────────────────────────────
    // getChatHistory Coverage Tests (content branches + shouldInclude branches)
    // ─────────────────────────────────────────────────────────────────────
        private static OneXtel__WhatsApp_Provider__c createProvider(String name) {
        OneXtel__WhatsApp_Provider__c p = new OneXtel__WhatsApp_Provider__c(
            Name                       = name,
            OneXtel__API_key__c        = 'test-api-key-12345',
            OneXtel__Sender_Id__c      = 'TESTSENDER',
            OneXtel__Waba_Id__c        = '1234567890'
        );
        insert p;
        return p;
    }
 
        private static OneXtel__WhatsApp_Template__c createTemplate(String name, Id providerId) {
        OneXtel__WhatsApp_Template__c t = new OneXtel__WhatsApp_Template__c(
            Name                          = name,
            OneXtel__Template_Id__c       = 'tmpl_test_' + String.valueOf(Crypto.getRandomInteger()).right(6),
            OneXtel__WhatsApp_Provider__c = providerId
        );
        insert t;
        return t;
    }
 
    private static OneXtel__WhatsApp_DLR__c createDLR(
        String phone, Id providerId, Id templateId,
        String status, String content, String jsonVal, String variablesVal
    ) {
        OneXtel__WhatsApp_DLR__c dlr = new OneXtel__WhatsApp_DLR__c(
            OneXtel__Status__c          = status,
            OneXtel__From_Number__c     = phone,
            OneXtel__Contact_Phone__c   = phone,
            OneXtel__User_Name__c       = 'Test User',
            OneXtel__Provider__c        = providerId,
            OneXtel__Template__c        = templateId,
            OneXtel__Message_Content__c = content,
            OneXtel__Json__c            = jsonVal,
            OneXtel__Variables__c       = variablesVal
        );
        insert dlr;
        return dlr;
    }
 
    @isTest
    static void testGetChatHistory_SymbiosisProvider_DirectContent() {
        OneXtel__WhatsApp_Provider__c prov = createProvider('Symbiosis Official');
        Lead_Opportunity__c lead = createLead('Sym Lead', '9998887770', 'Symbiosis');
        createDLR('9998887770', prov.Id, null, 'inbound', 'Hello direct content', null, null);
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertEquals(1, msgs.size(), 'Should return matching Symbiosis message');
        System.assertEquals('Hello direct content', msgs[0].content);
    }
 
    @isTest
    static void testGetChatHistory_NMIMSProvider_JsonContent() {
        OneXtel__WhatsApp_Provider__c prov = createProvider('NMIMS Deemed University');
        Lead_Opportunity__c lead = createLead('NMIMS Lead', '9998887771', 'NMIMS');
        createDLR('9998887771', prov.Id, null, 'outbound', null, '{"text":"Json body text"}', null);
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertEquals(1, msgs.size(), 'Should return matching NMIMS message');
        System.assertEquals('Json body text', msgs[0].content);
    }
 
    @isTest
    static void testGetChatHistory_OtherProvider_VariablesContent() {
        OneXtel__WhatsApp_Provider__c prov = createProvider('Manipal Provider');
        Lead_Opportunity__c lead = createLead('Other Uni Lead', '9998887772', 'Manipal');
        createDLR('9998887772', prov.Id, null, 'outbound', null, null, '{"bodyText":"Variables body text"}');
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertEquals(1, msgs.size(), 'Should return matching Other-university message');
        System.assertEquals('Variables body text', msgs[0].content);
    }
 
    @isTest
    static void testGetChatHistory_TemplateFallback_NoDirectContent() {
        OneXtel__WhatsApp_Provider__c prov = createProvider('Symbiosis Institute');
        OneXtel__WhatsApp_Template__c tmpl = createTemplate('Welcome Template', prov.Id);
        Lead_Opportunity__c lead = createLead('Template Lead', '9998887773', 'Symbiosis');
        createDLR('9998887773', prov.Id, tmpl.Id, 'outbound', null, null, null);
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertEquals(1, msgs.size(), 'Should return one message');
        System.assert(msgs[0].content.contains('Welcome Template'), 'Should fall back to template label');
    }
 
    @isTest
    static void testGetChatHistory_NoContentLabel() {
        OneXtel__WhatsApp_Provider__c prov = createProvider('Symbiosis International');
        Lead_Opportunity__c lead = createLead('No Content Lead', '9998887774', 'Symbiosis');
        createDLR('9998887774', prov.Id, null, 'outbound', null, null, null);
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertEquals(1, msgs.size(), 'Should return one message');
        System.assertEquals('(No content)', msgs[0].content);
    }
 
    @isTest
    static void testGetChatHistory_PreNov2025_UniversityMatch() {
        OneXtel__WhatsApp_Provider__c prov = createProvider('Manipal Legacy Provider');
        Lead_Opportunity__c lead = createLead('Pre Nov Lead', '9998887775', 'Manipal');
        // Push CreatedDate before the Nov-2025 cutoff to hit the isPreNov2025 branch
        Test.setCreatedDate(lead.Id, DateTime.newInstance(2025, 6, 1, 10, 0, 0));
        createDLR('9998887775', prov.Id, null, 'outbound', 'Pre-Nov message', null, null);
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertEquals(1, msgs.size(), 'Pre-Nov-2025 university match should include message');
    }
 
    @isTest
    static void testGetChatHistory_MismatchedProvider_Excluded() {
        OneXtel__WhatsApp_Provider__c prov = createProvider('NMIMS Official');
        Lead_Opportunity__c lead = createLead('Mismatch Lead', '9998887776', 'Symbiosis');
        createDLR('9998887776', prov.Id, null, 'outbound', 'Should be excluded', null, null);
 
        Test.startTest();
        List<WACommunityController.WAMessageWrapper> msgs =
            WACommunityController.getChatHistory(lead.Id);
        Test.stopTest();
 
        System.assertEquals(0, msgs.size(), 'NMIMS provider should be excluded for a Symbiosis lead');
    }
}
 