# ADR 001: WhatsApp Chat Component for Platform Users

## Status
Implemented ✅

## Context
Hike Education counsellors needed a WhatsApp chat interface 
embedded directly in the Lead Opportunity record page.

## Decision
Built a custom LWC component (`whatsAppChatHistory`) that:
- Fetches chat history via `WhatsAppChatController` (without sharing)
- Filters messages by university (NMIMS/Symbiosis/Others) using 
  provider name matching
- Supports template and freeform message sending via OneXtel package
- Auto-refreshes every 8 seconds using `setInterval`
- Sends bell notifications on inbound messages

## University Filtering Logic
| Lead University | Provider Filter |
|----------------|-----------------|
| Symbiosis | Provider name contains 'Symbiosis' |
| Others | Provider does NOT contain Symbiosis |
| Pre Nov 2025 | Provider contains exact university name |

## Consequences
- Platform users get real-time chat experience
- University isolation prevents cross-contamination of messages
- Phone numbers masked for sales reps (FLS bypass via without sharing)