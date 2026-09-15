# ADR 002: WhatsApp Chat Component for Partner Community Users

## Status
In Progress 🚧

## Context
40% of counsellors use Salesforce Partner Community licence which 
has different permission restrictions than Platform licence.

## Problem
OneXtel's `WhatsAppService.sendMessage()` internally throws 
`AuraHandledException` which can ONLY be called from:
- @AuraEnabled Apex context (LWC calls)
- Execute Anonymous
- REST API context

It CANNOT be called from:
- Triggers
- Scheduled Apex  
- Queueable Apex
- Platform Events

## Attempted Solutions
| Approach | Result | Reason |
|----------|--------|--------|
| Direct call (without sharing) | ❌ | Partner session blocks OneXtel |
| System.runAs | ❌ | Not allowed in production |
| Trigger on custom object | ❌ | Not Aura context |
| Scheduled Apex | ❌ | Not Aura context |
| Queueable Apex | ❌ | AuraHandledException not allowed |
| Platform Events | ❌ | Not Aura context |
| Named Credential REST | ❌ | No Connected App access |

## Root Cause
OneXtel's WhatsAppService validates it's being called from 
an Aura/VF context. Partner user sessions don't have 
sufficient OneXtel object-level permissions even with 
`without sharing` Apex.

## Solution
Sharing Rules on OneXtel objects give partner users READ access:
- WhatsApp Provider → Partner Users Group (Read)
- WhatsApp Template → Partner Users Group (Read)
- WhatsApp Report → Partner Users Group (Read/Write)

Combined with `without sharing` Apex called from `@AuraEnabled` 
context = messages send successfully.

## Decision
New component `whatsAppCommunityChat` with controller 
`WACommunityController` using this approach.