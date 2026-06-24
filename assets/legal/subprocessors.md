**Lintel**  
Subprocessor

Disclosure

Effective date: 14 June 2026

Version 1.0

Provider: The Tech Forge Ltd  ·  RC 8371716

**What this disclosure does.** This Disclosure lists the third parties ("Sub-processors") that Lintel engages to help provide the Service, where each is located, what data they handle, why we use them, and what safeguards apply. It supports our Data Processing Addendum and is required by the NDPA and GDPR.

# **Table of contents**

**1**  About this disclosure3

**2**  What is a sub-processor4

**3**  Current sub-processors — core platform6

**4**  Current sub-processors — communications9

**5**  Current sub-processors — payments10

**6**  Current sub-processors — analytics11

**7**  Current sub-processors — operations12

**8**  Affiliates as sub-processors13

**9**  International transfers14

**10**  Selection and due diligence16

**11**  Contractual safeguards17

**12**  Notification of changes19

**13**  Customer right to object20

**14**  Audit and oversight21

**15**  Termination of sub-processors22

**16**  Sub-processor incidents23

**17**  Changes to this disclosure24

**18**  Contact24

# **1\. About this disclosure**

## **1.1 Purpose**

This Subprocessor Disclosure (the "Disclosure") lists the Sub-processors that The Tech Forge Ltd ("Lintel," "we," "us," or "our") engages to help us provide the Lintel platform (the "Service"). For each Sub-processor, the Disclosure identifies:

* Their name and corporate identity;

* Their role and the functions they perform for Lintel;

* The categories of data they process;

* Where they store and process data;

* Key contractual and technical safeguards;

* Links to their privacy and security documentation.

## **1.2 Status**

This Disclosure is incorporated by reference into the Lintel Terms of Service, the Privacy Policy, and the Data Processing Addendum ("DPA"). It satisfies our obligation under the NDPA and GDPR to inform Customers of the identity of Sub-processors before they process personal data on Customers' behalf.

## **1.3 To whom this applies**

This Disclosure applies to:

* Customers (as the data controller of End Client personal data);

* End Clients (as data subjects whose personal data is processed);

* Lintel personnel responsible for vendor management;

* Regulators and auditors with lawful interest in our Sub-processor arrangements.

## **1.4 Living document**

This Disclosure is a living document. Sub-processors change as we add or remove vendors. The current canonical version is always published at getlintel.org/legal/subprocessors. The version published online prevails over any printed or saved copy.

**Plain English.** Lintel doesn't build everything ourselves. We use trusted third parties to host the database, deliver email, process payments, and run other parts of the Service. This document tells you who they are, what they do, and where they are.

# **2\. What is a sub-processor**

## **2.1 The processing chain**

Data protection law distinguishes between controllers, processors, and sub-processors:

* Controller: the party that determines the purposes and means of processing personal data. For most data in the Service, the Customer (agency) is the controller of End Client personal data.

* Processor: a party that processes personal data on behalf of a controller. Lintel is a processor when handling End Client data for Customers.

* Sub-processor: a processor engaged by Lintel (as primary processor) to perform some part of the processing on Lintel's behalf. Sub-processors do not have a direct contractual relationship with Customers, but their processing is governed by chains of contracts.

## **2.2 Roles within Lintel**

Within Lintel's operations, we have several different processing roles:

* As data controller: in respect of Customer account data (account profile, billing data, support correspondence) and Lintel-controlled marketing communications;

* As data processor: in respect of End Client data uploaded by Customers, processed strictly on their instructions;

* As joint controller: in limited cases involving Sub-processors that may operate as joint controllers for specific narrow purposes (such as fraud prevention).

## **2.3 Sub-processor categories**

We use Sub-processors across five categories of function:

* Core platform: hosting the application, database, file storage, and authentication infrastructure;

* Communications: delivering email, SMS, and other electronic messages;

* Payments: processing subscription payments and (where used) payments from End Clients;

* Analytics and monitoring: tracking application performance, errors, and (with consent) user analytics;

* Operations: supporting business functions such as customer support, internal communications, and document management.

## **2.4 What sub-processors do NOT do**

Sub-processors are bound by strict contractual limits. They do not:

* Receive Customer Data for purposes other than providing services to Lintel;

* Use Customer Data for their own marketing, advertising, or product development without explicit authorization;

* Re-sell or share Customer Data with their own third parties beyond what is necessary for their services;

* Maintain the data after termination of their engagement (except as required by law or for limited transition periods).

# **3\. Current sub-processors — core platform**

Core platform Sub-processors host the foundational infrastructure of the Service.

## **3.1 Supabase**

| Field | Detail |
| :---- | :---- |
| **Provider** | Supabase Inc. |
| **Role** | Database (PostgreSQL), file storage, authentication service, edge functions. |
| **Data processed** | All Customer Data: account records, clients, properties, contracts, bookings, payments, files, signatures. |
| **Processing location** | AWS US-East (Virginia) by default. Other regions may be available for enterprise Customers. |
| **Subprocessors of theirs** | Amazon Web Services (hosting); see Supabase's own Subprocessor list. |
| **Safeguards** | SOC 2 Type II certified; encryption at rest (AES-256) and in transit (TLS 1.2+); row-level security; daily backups; signed Data Processing Addendum with us. |
| **Privacy policy** | supabase.com/privacy |
| **Security documentation** | supabase.com/security |

## **3.2 Cloudflare**

| Field | Detail |
| :---- | :---- |
| **Provider** | Cloudflare, Inc. |
| **Role** | Content delivery network (CDN), DNS, DDoS protection, web application firewall (WAF), Pages hosting (app.getlintel.org). |
| **Data processed** | Public assets, application bundles, image previews; HTTP request metadata (IP addresses, user agents, request paths). |
| **Processing location** | Globally distributed edge network; closest edge to each user. Logs aggregated at Cloudflare's data centres. |
| **Safeguards** | ISO 27001, SOC 2 Type II certified; encryption in transit; signed Data Processing Addendum with us; supports EU Standard Contractual Clauses for international transfers. |
| **Privacy policy** | cloudflare.com/privacypolicy |
| **Security documentation** | cloudflare.com/trust-hub |

## **3.3 GitHub (for repositories and CI/CD)**

| Field | Detail |
| :---- | :---- |
| **Provider** | GitHub, Inc. (a subsidiary of Microsoft Corporation) |
| **Role** | Source code management, build automation (GitHub Actions), issue tracking. |
| **Data processed** | Lintel source code, build configurations, internal documentation. Customer Data is not stored in GitHub. |
| **Processing location** | United States; with global access points. |
| **Safeguards** | SOC 2 Type II; ISO 27001; encryption at rest and in transit; Microsoft Enterprise Agreement and DPA terms. |
| **Privacy policy** | docs.github.com/site-policy/privacy-policies/github-privacy-statement |
| **Security documentation** | github.com/security |

# **4\. Current sub-processors — communications**

## **4.1 Resend**

| Field | Detail |
| :---- | :---- |
| **Provider** | Resend, Inc. |
| **Role** | Transactional and marketing email delivery; engagement tracking (opens, clicks, bounces, complaints). |
| **Data processed** | Email content, recipient email addresses, sender identification, engagement events, delivery logs. |
| **Processing location** | United States (primary); with secondary infrastructure for resilience. |
| **Subprocessors of theirs** | Amazon Web Services (hosting); see Resend's own Subprocessor list. |
| **Safeguards** | SOC 2 Type II; encryption at rest and in transit; signed Data Processing Addendum; supports EU SCCs. |
| **Privacy policy** | resend.com/privacy |
| **Security documentation** | resend.com/security |

## **4.2 Zoho Mail (for inbound communications to Lintel)**

| Field | Detail |
| :---- | :---- |
| **Provider** | Zoho Corporation Pvt. Ltd. |
| **Role** | Email hosting for Lintel's own inboxes (@getlintel.org addresses such as hello@, billing@, privacy@). |
| **Data processed** | Inbound emails to Lintel staff. Includes Customer support correspondence, billing enquiries, legal notices. |
| **Processing location** | Primary processing in India and the United States, with regional data centres. |
| **Safeguards** | ISO 27001; SOC 2; encryption at rest and in transit. |
| **Privacy policy** | zoho.com/privacy.html |
| **Security documentation** | zoho.com/security.html |

Note: Zoho Mail handles inbound emails to Lintel staff. Outbound email from the Service to End Clients is handled by Resend (Section 4.1).

# **5\. Current sub-processors — payments**

## **5.1 Flutterwave**

| Field | Detail |
| :---- | :---- |
| **Provider** | Flutterwave Inc. / Flutterwave Technology Solutions Limited |
| **Role** | Payment processing for Customer subscription Fees and for End Client payments where applicable; KYC and fraud screening. |
| **Data processed** | Customer billing details (name, billing address, payment card token, last 4 digits, expiry), transaction amounts and currencies, KYC documents for higher-value transactions. |
| **Processing location** | Primary processing in Nigeria; certain functions in the United States. Card data is tokenized and stored under PCI-DSS standards. |
| **Safeguards** | PCI-DSS Level 1 certified; CBN-regulated as a payment service provider in Nigeria; encryption at rest and in transit; signed agreement with us. |
| **Privacy policy** | flutterwave.com/privacy-policy |
| **Security documentation** | flutterwave.com/security |

Important: When you pay through Flutterwave, you also accept Flutterwave's own terms and privacy policy in respect of payment processing. Lintel does not store full card numbers, CVV codes, or PIN data — these are handled directly by Flutterwave under PCI-DSS.

# **6\. Current sub-processors — analytics and monitoring**

## **6.1 Sentry**

| Field | Detail |
| :---- | :---- |
| **Provider** | Functional Software, Inc. dba Sentry |
| **Role** | Application error tracking, performance monitoring, crash reporting (for the web and mobile applications). |
| **Data processed** | Error stack traces, request metadata (URL, HTTP method, status code, IP address), browser and device fingerprints, user identifier (Lintel internal ID, not personal data), breadcrumbs of recent user actions. |
| **Processing location** | United States (primary); EU region available for EU-Customer specific configurations. |
| **Safeguards** | SOC 2 Type II; ISO 27001; encryption at rest and in transit; PII scrubbing configured on our side to avoid sending sensitive data; signed Data Processing Addendum. |
| **Privacy policy** | sentry.io/privacy |
| **Security documentation** | sentry.io/security |

## **6.2 Google Analytics (with consent only)**

| Field | Detail |
| :---- | :---- |
| **Provider** | Google LLC |
| **Role** | Web analytics on the marketing site (getlintel.org), where the visitor has consented. |
| **Data processed** | Page views, session events, referrers, browser and device data, anonymized IP address (IP anonymization enabled). |
| **Processing location** | Globally distributed; Lintel uses Google Analytics 4 with IP anonymization. |
| **Safeguards** | ISO 27001, ISO 27017, ISO 27018; SOC 2 / SOC 3; configured for IP anonymization; Google's data processing terms; supports EU SCCs and additional measures for international transfers. |
| **Privacy policy** | policies.google.com/privacy |
| **Security documentation** | cloud.google.com/security |

Note: Google Analytics is loaded only after Customer consent through our cookie banner. See the Cookie Policy for details.

# **7\. Current sub-processors — operations**

## **7.1 Google Workspace**

| Field | Detail |
| :---- | :---- |
| **Provider** | Google LLC |
| **Role** | Internal collaboration tools: Google Drive, Google Docs, Google Calendar for Lintel internal operations. |
| **Data processed** | Internal Lintel documents, may incidentally include Customer correspondence where Customers send documents to Lintel staff. Not used to host Customer-controlled End Client personal data systematically. |
| **Processing location** | Globally distributed; data residency available for some products. |
| **Safeguards** | ISO 27001, ISO 27017, ISO 27018; SOC 2/3; encryption at rest and in transit; Google Cloud DPA. |
| **Privacy policy** | policies.google.com/privacy |
| **Security documentation** | workspace.google.com/security |

## **7.2 Apple (for iOS distribution)**

| Field | Detail |
| :---- | :---- |
| **Provider** | Apple Inc. |
| **Role** | App Store distribution of the Lintel iOS application, including device identifier (IDFV) processing, app analytics where consented, and push notification routing through APNs. |
| **Data processed** | Device-level identifiers, app installation events, push notification delivery records. |
| **Processing location** | United States; Apple's global infrastructure. |
| **Safeguards** | Apple Developer Program agreement; App Store Review Guidelines; encryption in transit; Apple Tracking Transparency framework respected. |
| **Privacy policy** | apple.com/legal/privacy |
| **Security documentation** | apple.com/privacy |

## **7.3 Google (for Android distribution and Firebase)**

| Field | Detail |
| :---- | :---- |
| **Provider** | Google LLC |
| **Role** | Google Play distribution of the Lintel Android application; push notifications via Firebase Cloud Messaging (FCM). |
| **Data processed** | Device-level identifiers (Android app-set ID, not advertising ID), app installation events, push notification delivery. |
| **Processing location** | Globally distributed; Firebase Cloud Messaging routes through Google data centres. |
| **Safeguards** | Google Developer Distribution Agreement; Play Store policies; encryption in transit; Firebase Data Processing Terms. |
| **Privacy policy** | policies.google.com/privacy |
| **Security documentation** | developers.google.com/privacy |

# **8\. Affiliates as sub-processors**

## **8.1 Lintel affiliates**

Where Lintel has affiliated companies (such as branches, subsidiaries, or related entities of The Tech Forge Ltd), they may process Customer Data on the same basis as Lintel itself. As of the effective date:

* The Tech Forge Ltd has no separately incorporated affiliates processing Customer Data;

* All Lintel processing operations are conducted directly by The Tech Forge Ltd.

If we engage affiliates in the future, this section will be updated and Customers notified in accordance with Section 12\.

## **8.2 Internal contractors**

Lintel engages external contractors (such as freelance designers, developers, or specialist consultants) from time to time. Where such contractors process Customer Data:

* They are bound by written confidentiality and data protection agreements with terms no less protective than this Disclosure and our DPA;

* Their access is limited to what is necessary for their specific task;

* They are not separately listed in this Disclosure unless they have a material ongoing role processing Customer Data;

* Their engagements are reviewed periodically.

Customers can request, on reasonable notice, a list of current contractors with material Customer Data access by writing to dpo@getlintel.org.

# **9\. International transfers**

## **9.1 Where data flows**

Lintel is based in Nigeria. Many of our Sub-processors are based outside Nigeria. Consequently, Customer Data is transferred internationally, primarily to:

| Region | Why |
| :---- | :---- |
| **United States** | Supabase, GitHub, Resend, Sentry, Google, Apple, and Flutterwave (for some functions) are US-headquartered. Most data therefore transits or rests in the US. |
| **European Union** | Some Sub-processors offer EU-region deployments; Cloudflare's edge nodes include EU locations; in-flight data may transit EU networks. |
| **Globally distributed** | Cloudflare and Google operate globally distributed networks; specific data location for in-flight requests depends on the recipient's network proximity. |
| **India** | Zoho Mail primary processing for our inbound corporate email. |
| **Nigeria** | Some Flutterwave processing; Lintel's own internal records. |

## **9.2 NDPA position on transfers**

The NDPA permits transfer of personal data outside Nigeria where adequate safeguards are in place. This is achieved through:

* Adequacy decisions by the NDPC (where issued);

* Binding contractual arrangements with Sub-processors;

* Consent of the data subject where required;

* Necessity for the performance of the contract with the data subject.

## **9.3 GDPR position on transfers**

Where Customer Data includes personal data of EU or UK data subjects, GDPR / UK GDPR rules on international transfers apply. Lintel relies on:

* EU Standard Contractual Clauses (SCCs) 2021/914 in our agreements with Sub-processors outside adequacy-decision countries;

* UK International Data Transfer Agreement (IDTA) or UK Addendum to the SCCs for UK-data transfers;

* Transfer impact assessments where required to verify SCC safeguards remain effective in light of recipient-country laws;

* Supplementary technical measures (such as strong encryption with keys under Lintel control or in a friendly jurisdiction) where necessary.

## **9.4 Where you object to transfers**

If you have specific concerns about transfers to particular jurisdictions:

* Contact dpo@getlintel.org to discuss;

* In some cases, we may be able to provide region-specific processing arrangements (typically as part of an Enterprise plan);

* Where we cannot accommodate your requirements, you may terminate your subscription in line with the Terms.

# **10\. Selection and due diligence**

## **10.1 How we select Sub-processors**

Before engaging any Sub-processor that will process Customer Data, we conduct due diligence covering:

* Security: certifications (SOC 2, ISO 27001 preferred), encryption practices, vulnerability management, incident history;

* Compliance: alignment with the NDPA, GDPR, and other Applicable Law; willingness to enter into appropriate data protection contracts;

* Operational reliability: track record, uptime, support quality, financial stability;

* Geographic considerations: location of processing, transfer safeguards available;

* Sub-processor chain: how they manage their own sub-processors;

* Specific use case fit: whether the Sub-processor's offering matches our actual needs without unnecessary data exposure.

## **10.2 Documentation**

We document, for each Sub-processor:

* The reason for selection;

* The due diligence undertaken;

* The risk assessment outcome;

* Signed contractual terms (DPA, SCCs where applicable);

* Periodic review dates.

## **10.3 Periodic review**

Sub-processor relationships are reviewed at least annually, or sooner where:

* A security incident has occurred at the Sub-processor;

* The Sub-processor has changed ownership, jurisdiction, or material practices;

* Applicable Law has changed in ways that affect the relationship;

* Our use of the Sub-processor has materially changed.

Reviews may result in continuation, renegotiation, or replacement.

# **11\. Contractual safeguards**

## **11.1 DPA terms**

Every Sub-processor processing Customer personal data is bound by terms no less onerous than those Lintel undertakes to Customers under the DPA, including:

* Processing only on documented instructions from Lintel;

* Confidentiality obligations on Sub-processor personnel;

* Implementation of appropriate technical and organizational measures (TOMs) to ensure security;

* Assistance with data subject rights and breach notification;

* Audit rights;

* Return or deletion of data on termination;

* Pass-down of obligations to their own sub-processors.

## **11.2 Standard Contractual Clauses**

Where transfers of personal data outside the EU/EEA, UK, or other restricted regions occur, contracts include the relevant Standard Contractual Clauses or equivalent transfer mechanism:

* EU SCCs 2021/914 modules 2 (controller-to-processor) or 3 (processor-to-sub-processor) as appropriate;

* UK International Data Transfer Agreement or UK Addendum to the SCCs;

* Equivalent under other regimes where Lintel processes data subject to those regimes.

## **11.3 Sub-processor's own Sub-processors**

Sub-processors are required to:

* Maintain their own current list of sub-processors;

* Notify Lintel of changes to that list with reasonable advance notice;

* Bind their sub-processors to terms equivalent to those they have agreed with us;

* Remain liable to Lintel for the acts and omissions of their sub-processors.

## **11.4 Security and incident response**

Sub-processors must:

* Implement appropriate security measures, including encryption at rest and in transit, access controls, and monitoring;

* Notify Lintel without undue delay (typically within 24-72 hours) of any security incident affecting Customer Data;

* Assist Lintel in fulfilling its own notification obligations to Customers and regulators;

* Cooperate in investigation and remediation of incidents.

# **12\. Notification of changes**

## **12.1 Our commitment**

When we propose to add, remove, or replace a Sub-processor that materially affects how Customer Data is processed, we will notify Customers in advance.

## **12.2 Standard notification**

For additions, replacements, or material changes to Sub-processors, we will:

* Update this Disclosure on getlintel.org/legal/subprocessors;

* Notify Customers by email at least 14 days before the change takes effect;

* Post in-product notifications where appropriate;

* Provide reasons for the change and information about the new Sub-processor.

## **12.3 Expedited changes**

In rare circumstances, we may need to add or replace a Sub-processor on shorter notice, including:

* Security or operational emergencies requiring immediate replacement;

* Termination of an existing Sub-processor;

* Regulatory requirements;

* Force majeure events affecting the existing Sub-processor.

Where we make an expedited change, we will notify Customers as soon as practicable and explain the reasons.

## **12.4 Removals**

Where we cease using a Sub-processor:

* We update the Disclosure;

* We ensure Customer Data is returned or deleted by the outgoing Sub-processor within contractually required timelines;

* We notify Customers if the change affects their experience (such as a region change or feature deprecation).

## **12.5 Subscribe to notifications**

Customers who want to be notified of all Sub-processor changes (not only those affecting their account) can subscribe by emailing dpo@getlintel.org with the request "subscribe me to subprocessor notifications."

# **13\. Customer right to object**

## **13.1 Right to object**

If you reasonably object to a proposed new or replacement Sub-processor on data protection grounds, you may notify us in writing within 14 days of the notification under Section 12\. Reasonable grounds for objection include:

* The new Sub-processor's location or jurisdiction creates specific compliance concerns for your business;

* The new Sub-processor's privacy or security practices fall materially short of those of the Sub-processor it replaces;

* The new Sub-processor's role results in additional categories of data being processed without your authorization;

* The change conflicts with specific commitments made in your Order Form.

## **13.2 What happens after objection**

On receiving an objection:

* We will discuss the concerns with you;

* Where possible, we will adjust the engagement (such as configuring the Sub-processor for region-specific processing, restricting data categories, or offering an alternative);

* Where the objection cannot be resolved, you may terminate the affected subscription;

* If termination occurs because of an unresolved good-faith objection to a Sub-processor change, we will refund prepaid Fees for the unused portion of the Subscription Term as your sole remedy.

## **13.3 Not a reason to object**

The right to object is not a general right to veto Sub-processor changes. We do not consider as reasonable grounds for objection:

* Mere preference for a different vendor;

* Concerns that are unrelated to data protection (such as commercial preferences);

* Concerns that could equally apply to most cloud-based Sub-processors and that you have not raised before.

# **14\. Audit and oversight**

## **14.1 Lintel's oversight**

We maintain ongoing oversight of Sub-processors, including:

* Monitoring their security advisories and incident notifications;

* Reviewing their published security and certification reports;

* Reviewing changes to their privacy practices;

* Periodic compliance and performance reviews;

* Tracking their sub-processor changes.

## **14.2 Customer audit rights**

Customers have audit rights under the DPA. In respect of Sub-processors, this means:

* We will provide reasonable information about our Sub-processor due diligence on request;

* We will share Sub-processors' published reports (SOC 2, ISO 27001, etc.) where we are permitted to;

* We will facilitate (subject to confidentiality and reasonable scope) Customer audits where required by Applicable Law;

* Direct audits of Sub-processors by Customers are not generally available — we rely on Sub-processors' own published audits and certifications.

## **14.3 Regulatory oversight**

Where the NDPC, EU/UK supervisory authorities, or other regulators conduct oversight involving our Sub-processors, we:

* Cooperate fully with the regulator;

* Notify affected Customers if the oversight has material implications for their processing;

* Maintain records of regulatory engagements for accountability.

# **15\. Termination of sub-processors**

## **15.1 When we terminate a Sub-processor**

We may terminate a Sub-processor relationship for reasons including:

* Material breach of contractual obligations;

* Material security incidents the Sub-processor failed to handle adequately;

* Changes in our needs or technical architecture;

* Better alternatives becoming available;

* Regulatory requirements;

* Cost or commercial considerations.

## **15.2 Transition process**

When terminating a Sub-processor that holds Customer Data:

* We arrange for Customer Data to be migrated to a replacement Sub-processor (or to our own infrastructure);

* We verify the Sub-processor has deleted Customer Data after migration, subject to any legal retention obligations applicable to them;

* We document the termination and verify safeguards remained intact throughout transition;

* We notify Customers of the transition where it affects them.

## **15.3 Sub-processor business failure**

If a Sub-processor becomes insolvent, ceases operations, or otherwise becomes unable to continue providing services:

* We invoke business-continuity arrangements (which may include backup Sub-processors for critical functions);

* We act to retrieve Customer Data before the Sub-processor's systems become unavailable;

* We notify Customers of the impact and remedial steps.

# **16\. Sub-processor incidents**

## **16.1 Notification obligations**

Each Sub-processor is contractually required to notify Lintel without undue delay of:

* Security incidents affecting Customer Data;

* Personal data breaches;

* Material service outages;

* Regulatory enforcement actions affecting them;

* Changes in their sub-processors or processing practices that may affect us.

## **16.2 Our response**

On receiving notification from a Sub-processor:

* We treat it as a Lintel Incident and follow the Incident Response Policy (Section 20 of that Policy);

* We classify severity based on impact to Lintel and our Customers;

* We notify affected Customers in accordance with our DPA obligations and the Incident Response Policy timelines;

* We coordinate with the Sub-processor on containment, remediation, and communication.

## **16.3 Notification to you**

Where a Sub-processor incident affects your Customer Data:

* We notify you (typically within 24-72 hours of becoming aware, depending on the nature of the incident);

* We provide such information as we have at the time, supplementing with further information as it emerges;

* We support you in meeting your own notification obligations as a controller (to authorities and data subjects);

* We document the incident in our breach register.

# **17\. Changes to this disclosure**

We may update this Disclosure from time to time to reflect changes in our Sub-processors or in how we manage them. When we make changes:

* We update the "Effective date" at the top of this Disclosure;

* For material changes (new Sub-processors, removal of Sub-processors, changes to processing locations), we follow the notification process in Section 12;

* For non-material changes (clarifications, contact details, typo corrections), the change takes effect on publication.

# **18\. Contact**

For questions about Sub-processors or this Disclosure:

| Purpose | Contact |
| :---- | :---- |
| **Sub-processor and DPA questions** | dpo@getlintel.org |
| **Privacy enquiries generally** | privacy@getlintel.org |
| **Subscribe to notifications of changes** | dpo@getlintel.org |
| **Object to a proposed change** | dpo@getlintel.org |
| **Audit requests** | dpo@getlintel.org |
| **Legal questions about this Disclosure** | legal@getlintel.org |
| **General product support** | hello@getlintel.org |
| **Postal address** | The Tech Forge Ltd, 27 Carter Street, Ebute Metta, Lagos, Nigeria |

We aim to acknowledge enquiries within 5 working days. Urgent matters concerning Sub-processor incidents should be marked urgent in the subject line.

*End of Subprocessor Disclosure*

Lintel · Version 1.0 · Effective 14 June 2026 · The Tech Forge Ltd · RC 8371716

*The current Sub-processor list is always available at getlintel.org/legal/subprocessors. The online version prevails over any printed or saved copy.*