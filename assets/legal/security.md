**Lintel**  
Security Policy

Effective date: 14 June 2026

Version 1.0

Provider: Techforge Developers Limited  ·  RC 8371716

**What this policy does.** This Policy describes the technical and organizational measures Lintel applies to protect the confidentiality, integrity, and availability of the Service and Customer Data. It is the preventive companion to the Incident Response Policy and supports our obligations under the NDPA, GDPR, and security commitments to Customers.

# **Table of contents**

**1**  About this policy3

**2**  Security principles and objectives5

**3**  Security governance7

**4**  Information classification9

**5**  Infrastructure security11

**6**  Network and perimeter security13

**7**  Application security15

**8**  Identity and access management17

**9**  Encryption19

**10**  Authentication and credentials21

**11**  Secure development lifecycle23

**12**  Change management25

**13**  Logging, monitoring, and detection26

**14**  Vulnerability management28

**15**  Patch management30

**16**  Backup and disaster recovery31

**17**  Business continuity33

**18**  Endpoint security34

**19**  Physical security35

**20**  Third-party risk management36

**21**  Human resources security37

**22**  Security training and awareness39

**23**  Coordinated vulnerability disclosure40

**24**  Customer-side security responsibilities42

**25**  Compliance and audit44

**26**  Changes to this policy45

**27**  Contact45

# **1\. About this policy**

## **1.1 Purpose**

This Security Policy (the "Policy") describes the technical and organizational measures ("TOMs") that Techforge Developers Limited ("Lintel," "we," "us," or "our") implements to protect the Lintel platform (the "Service") and the data we hold within it.

Its objectives are to:

* Protect the confidentiality, integrity, and availability of Customer Data and our own systems;

* Set out the security framework our team operates within;

* Inform Customers, regulators, auditors, and other stakeholders of our security posture;

* Support our compliance with the NDPA, GDPR, and other Applicable Law;

* Provide the foundation for trust between Lintel and the agencies that depend on us;

* Pair with the Incident Response Policy (the reactive complement) to cover the full security lifecycle.

## **1.2 Status**

This Policy forms part of the Lintel Terms of Service and is incorporated by reference into the Privacy Policy and Data Processing Addendum. Capitalised terms used but not defined in this Policy have the meanings given in the Terms or the Privacy Policy.

## **1.3 To whom this applies**

This Policy applies to:

* Lintel personnel, including all employees, contractors, and authorized representatives;

* Sub-processors who handle Customer Data on Lintel's behalf, through contractual obligations imposed on them;

* Customers, in respect of customer-side responsibilities set out in Section 24;

* Anyone interacting with the Service, in respect of the security requirements that apply to their interactions.

## **1.4 Relationship to other policies**

This Policy works alongside:

* Incident Response Policy: how we respond when security incidents occur;

* Acceptable Use Policy: conduct that may compromise security;

* Privacy Policy and DPA: how we handle personal data, including security measures;

* Subprocessor Disclosure: third parties who must meet equivalent security standards;

* Data Retention Policy: how long data is kept and when it is destroyed.

## **1.5 Living document**

Security is not static. This Policy is a living document, reviewed at least annually and updated when material changes occur. The current canonical version is always published at getlintel.org/legal/security.

**Plain English.** We take security seriously. This document tells you what we do — encryption, access controls, monitoring, secure coding, vulnerability management, and so on — and what you need to do on your side. It's the preventive sibling of the Incident Response Policy: that one is for when things go wrong; this one is for keeping things from going wrong in the first place.

# **2\. Security principles and objectives**

## **2.1 The CIA triad**

Our security programme is built around the three classic information security objectives:

* Confidentiality: Customer Data and Lintel-internal information should be accessible only to authorized persons and systems;

* Integrity: data and systems should not be altered, corrupted, or destroyed without authorization;

* Availability: the Service and the data it holds should be available to authorized users when needed.

## **2.2 Defence in depth**

We do not rely on any single control to keep us secure. We implement layered defences, so that if one control fails or is bypassed, others remain to contain or detect the issue. Layers include:

* Perimeter (CDN, WAF, DDoS protection);

* Network (segmentation, traffic filtering);

* Host (operating-system hardening, endpoint protection);

* Application (input validation, parameterized queries, output encoding);

* Data (encryption, access controls, row-level security);

* Identity (strong authentication, least privilege, lifecycle management);

* Monitoring and detection (logging, alerting, anomaly detection);

* Process and people (training, vetting, separation of duties).

## **2.3 Least privilege**

Every user, system component, and integration is granted the minimum access necessary for its function. Access is reviewed periodically. Elevated access is granted only on demonstrated need, time-limited where possible, and audited.

## **2.4 Secure by default**

New features, components, and integrations are designed and configured to be secure by default. Insecure configurations require explicit, justified opt-in by Lintel personnel.

## **2.5 Continuous improvement**

Threats and best practices evolve. We continuously assess and improve our security posture through:

* Industry threat intelligence;

* Internal post-incident reviews;

* External audits and penetration tests;

* Regulator guidance;

* Peer learning and security community engagement.

## **2.6 Risk-based approach**

We allocate security investment proportionately to risk. We do not over-engineer protection of low-sensitivity data, nor under-protect high-sensitivity data. Decisions are documented in a security risk register reviewed by senior management.

## **2.7 Transparency**

We are honest with Customers about our security practices, limitations, and incidents. We do not over-claim capabilities. Where we do not yet have a control in place, we say so.

# **3\. Security governance**

## **3.1 Accountability**

Overall accountability for information security rests with Lintel's senior management. Day-to-day responsibility is distributed across:

| Role | Responsibilities |
| :---- | :---- |
| **Senior management** | Approves security strategy and budget; reviews risk register; accountable to regulators and customers. |
| **Security Lead** | Designs and operates the security programme; runs the risk register; coordinates incident response. |
| **Engineering Lead** | Implements security controls in product and infrastructure; secure development; vulnerability remediation. |
| **Data Protection Officer (DPO)** | Oversees personal data protection compliance; liaises with NDPC and other supervisory authorities; advises on data-related security risks. |
| **Operations** | Manages production access, change management, monitoring, and backup. |
| **All Lintel personnel** | Comply with this Policy, complete security training, report suspected incidents, and apply good security hygiene in daily work. |

## **3.2 Security risk register**

We maintain a security risk register that:

* Identifies threats to the Service, Customer Data, and our own operations;

* Assesses likelihood and impact of each;

* Records mitigations in place;

* Records accepted residual risk;

* Is reviewed quarterly and after material events.

## **3.3 Policy framework**

This Policy sits within a broader policy framework that includes:

* Internal security standards (specifying technical controls for particular systems);

* Operational procedures (step-by-step guides for personnel);

* Standards of conduct (such as acceptable use of company devices);

* Vendor management policies.

Internal standards and procedures are not published externally for security reasons but are available on reasonable request to enterprise Customers under non-disclosure agreement.

## **3.4 Policy review**

This Policy is reviewed at least annually and updated for:

* Material changes to our technology stack or operations;

* New threats or attack patterns;

* Changes in Applicable Law or regulator guidance;

* Lessons learned from incidents and post-incident reviews;

* Feedback from audits, customer due diligence, and security research.

# **4\. Information classification**

## **4.1 Categories**

Information handled within Lintel is classified into four categories, each with different handling requirements:

| Class | Definition | Examples |
| :---- | :---- | :---- |
| **Public** | Information intended for public disclosure. | Marketing site content; legal policies; status page entries. |
| **Internal** | Information for Lintel personnel and authorized third parties. | Internal documentation; build artefacts; meeting notes. |
| **Confidential** | Information whose unauthorized disclosure would cause material harm. | Customer Data; non-public product roadmap; commercial terms with vendors. |
| **Restricted** | Highest-sensitivity information requiring additional controls. | Cryptographic keys; production credentials; signed-contract audit trails; payment card tokens. |

## **4.2 Handling requirements**

Each classification has handling requirements covering:

* Storage location and encryption;

* Access controls and authentication strength required;

* Sharing rules (internal, with whom, under what authorization);

* Retention and disposal;

* Use in development, testing, and demonstration.

## **4.3 Customer Data classification**

Customer Data is by default classified as Confidential. Specific sub-categories may be elevated to Restricted, including:

* Signed contracts and their audit trails;

* KYC documents and identity scans;

* Payment card data (which we tokenize via the Payment Processor and do not hold in raw form);

* Sensitive personal data (such as health, biometric, financial data, where present).

# **5\. Infrastructure security**

## **5.1 Hosting architecture**

The Lintel platform runs on cloud infrastructure delivered through:

* Supabase (database, file storage, authentication, edge functions);

* Cloudflare (CDN, DNS, WAF, DDoS protection, Pages hosting for the application);

* Resend (email delivery infrastructure);

* Other Sub-processors as listed in the Subprocessor Disclosure.

All providers maintain industry-recognized security certifications (SOC 2 Type II, ISO 27001, or equivalent) and operate enterprise-grade physical and network security at their data centres.

## **5.2 Multi-region resilience**

Critical components are configured for resilience:

* Database backups are replicated across multiple geographic regions;

* Cloudflare's edge network provides geographically distributed delivery of the application;

* DNS is operated with high availability and failover.

## **5.3 Environment separation**

We maintain logically separated environments:

* Production: serves live Customers; access strictly limited;

* Staging: pre-release validation; mirrors production but uses synthetic or anonymized data;

* Development: individual engineer environments; isolated from production data and credentials.

Production data does not flow into staging or development. Where realistic data is needed for testing, we use anonymized or synthetic data.

## **5.4 Hardening**

Infrastructure is hardened in line with vendor and industry guidance, including:

* Removing unused services and ports;

* Disabling default accounts and changing default credentials;

* Applying secure configurations (such as Center for Internet Security benchmarks where applicable);

* Regular configuration drift detection and remediation.

## **5.5 Containerization and isolation**

Where the application uses containers or serverless functions, each is isolated and configured with minimal privileges. Container images are scanned for known vulnerabilities before deployment.

# **6\. Network and perimeter security**

## **6.1 Cloudflare as perimeter**

All public traffic to Lintel's web properties is routed through Cloudflare's edge network, which provides:

* DDoS mitigation at the edge (including volumetric, protocol, and application-layer attacks);

* Web Application Firewall (WAF) rules that block common attack patterns;

* Bot management to detect and mitigate scrapers and credential stuffing;

* Rate limiting and traffic shaping;

* TLS termination with modern cipher suites only.

## **6.2 TLS**

All public connections to the Service use Transport Layer Security:

* TLS 1.2 or higher; TLS 1.0 and 1.1 are disabled;

* Modern cipher suites only (no RC4, no 3DES, no NULL ciphers);

* HTTP Strict Transport Security (HSTS) enforced;

* Certificates managed automatically (with autorenewal) through Cloudflare or Let's Encrypt;

* Certificate Transparency monitoring for unauthorized issuance.

## **6.3 Internal network**

Internal traffic between Lintel-managed components uses encrypted channels. We do not assume that internal networks are inherently trustworthy — even internal services authenticate to each other.

## **6.4 API security**

Our APIs are protected by:

* Authentication on every request (no anonymous access to non-public endpoints);

* Authorization checks based on the authenticated user's permissions and tenant scope;

* Rate limiting per user, per IP, and per endpoint;

* Input validation against schemas;

* Output filtering to ensure no Cross-Tenant data leaks.

## **6.5 Egress controls**

Outbound connections from production are restricted:

* Connections to known sub-processor endpoints are allowed;

* Connections to arbitrary destinations are not — preventing data exfiltration in many attack scenarios.

# **7\. Application security**

## **7.1 Authentication**

Customer authentication is handled through Supabase Auth, which provides:

* Email/password authentication with strong password requirements;

* Multi-factor authentication (MFA) support;

* Magic-link authentication for low-friction sign-in;

* OAuth integration with major identity providers (Google, Apple);

* PKCE flow for OAuth and magic-link redemption;

* Token rotation and refresh-token revocation on logout.

## **7.2 Authorization and tenant isolation**

Lintel is multi-tenant — many agencies share the same infrastructure. Strict tenant isolation is enforced at multiple levels:

* Application layer: every request is associated with a specific tenant; cross-tenant access is rejected;

* Database layer: Supabase row-level security (RLS) policies enforce that database queries can return only rows belonging to the authenticated tenant;

* File storage: Supabase Storage policies enforce that signed URLs can only reference files within the authenticated tenant;

* Engineering reviews: all new features that touch tenant-scoped data are reviewed for tenant isolation.

## **7.3 Input validation**

All inputs are validated:

* At the API edge: schema validation rejects malformed requests;

* At the database layer: parameterized queries prevent SQL injection;

* At the rendering layer: outputs are encoded to prevent cross-site scripting (XSS);

* At file upload: content-type checks, size limits, malware scanning where applicable.

## **7.4 Common vulnerability classes**

Specific defences against common vulnerability classes:

* SQL injection: parameterized queries; no string-concatenated SQL in business code;

* Cross-site scripting (XSS): output encoding, Content Security Policy (CSP) headers;

* Cross-site request forgery (CSRF): anti-CSRF tokens for state-changing requests;

* Server-side request forgery (SSRF): allow-listed URL fetching;

* Insecure direct object references: authorization checks on every record access;

* Excessive data exposure: response shaping to return only data the user is entitled to see;

* Mass assignment: explicit allow-lists for user-modifiable fields.

## **7.5 Session management**

Session security:

* Cookies marked HttpOnly and Secure;

* Same-Site cookies (typically Lax or Strict);

* Reasonable session lifetimes with refresh-token rotation;

* Logout terminates the active session and revokes refresh tokens;

* Concurrent session limits where appropriate.

## **7.6 Headers**

Security HTTP headers are set on responses:

* Strict-Transport-Security (HSTS);

* Content-Security-Policy (CSP);

* X-Content-Type-Options: nosniff;

* X-Frame-Options or CSP frame-ancestors directive;

* Referrer-Policy;

* Permissions-Policy.

# **8\. Identity and access management**

## **8.1 Personnel access**

Lintel personnel access to production systems is governed by:

* Need-to-know: access only where required for a specific role and task;

* Least privilege: minimum permissions necessary;

* Strong authentication: multi-factor required for production access;

* Centralized identity management: all access tied to identity records, not shared accounts;

* Access logging: every production access is logged;

* Periodic review: access reviewed at least quarterly.

## **8.2 Privileged access**

Privileged access (administrative, root, or equivalent) is subject to additional controls:

* Stronger authentication (hardware key MFA where possible);

* Just-in-time elevation (privileged access granted for specific tasks, then revoked);

* Pair review for high-impact actions (such as database schema changes);

* Detailed logging of privileged actions;

* Periodic recertification.

## **8.3 Service accounts**

Non-human accounts used by automation:

* Are scoped to specific functions;

* Use strong, rotated credentials (typically short-lived tokens);

* Are not shared between unrelated services;

* Are inventoried and reviewed.

## **8.4 Authorized User access**

Within Customer accounts, Authorized Users are managed by the Customer through Lintel's user management features. Lintel provides:

* Role-based access control (administrator, manager, accountant, agent, etc.);

* Custom role definitions where the Plan supports them;

* Audit logs showing who accessed or modified what;

* Session management tools (active sessions, forced sign-out).

## **8.5 Lifecycle management**

Access is managed through the lifecycle of a relationship:

* Onboarding: access provisioned based on role at the start of an engagement;

* Change of role: access adjusted within reasonable time of role change;

* Off-boarding: access revoked promptly when employment or engagement ends (target: within 24 hours of departure for personnel; immediately for security-sensitive roles);

* Dormant accounts: detected and reviewed; inactive accounts disabled after a defined period.

# **9\. Encryption**

## **9.1 In transit**

All Customer-facing connections to the Service use TLS 1.2 or higher with modern cipher suites. This applies to:

* Web traffic to getlintel.org and app.getlintel.org;

* Mobile application connections;

* API connections;

* Outbound email (using STARTTLS opportunistically);

* Internal traffic between trusted components.

## **9.2 At rest**

Customer Data is encrypted at rest at the storage layer:

* Database: AES-256 disk encryption applied by Supabase / AWS;

* File storage: AES-256 encryption applied by Supabase Storage;

* Backups: encrypted at rest with separate keys;

* Logs: encrypted at rest in the relevant log storage.

## **9.3 Application-layer encryption**

Some categories of data receive an additional application-layer encryption beyond the storage default, including:

* Authentication secrets (e.g., user passwords hashed with strong adaptive functions such as bcrypt or Argon2);

* API keys and tokens stored in encrypted form;

* Webhook signing secrets stored in protected configuration.

## **9.4 Key management**

Cryptographic keys are managed with the following principles:

* Stored in dedicated key management infrastructure (Sub-processor key management services);

* Access to keys is limited to a small number of authorized personnel;

* Rotation: keys are rotated periodically and on suspected compromise;

* Separation: encryption keys are stored separately from the data they protect;

* Backups of key material follow the same security model as the keys themselves.

## **9.5 Algorithms**

Approved algorithms include:

* Symmetric encryption: AES-256;

* Public-key cryptography: RSA-2048 or higher; ECC P-256 or higher;

* Hashing: SHA-256 or stronger; password hashing using bcrypt, Argon2, or equivalent adaptive hashes;

* Random number generation: cryptographically secure (CSPRNG) only;

* Deprecated algorithms (MD5, SHA-1 for security purposes, RC4, 3DES) are not used.

# **10\. Authentication and credentials**

## **10.1 Password requirements**

Customer passwords must:

* Be at least 10 characters long;

* Not be one of the most commonly known compromised passwords;

* Not be the user's email address or obvious variations;

* Be checked against known breach databases (such as Have I Been Pwned) where possible.

We follow modern NIST guidance: prioritising length and breach-list screening over complexity rules that encourage predictable patterns.

## **10.2 Multi-factor authentication**

Multi-factor authentication (MFA) is supported and strongly encouraged. Where supported by the Plan:

* Time-based one-time passwords (TOTP) via authenticator apps;

* WebAuthn / FIDO2 for hardware key support (planned);

* Recovery codes for backup access;

* Administrative ability for Customers to require MFA for their Authorized Users.

Lintel personnel with access to production systems are required to use MFA.

## **10.3 Single sign-on**

Where the Plan supports it, Single Sign-On (SSO) with major identity providers (Google, Microsoft, OAuth-compatible enterprise IdPs) is available, providing:

* Centralized authentication controlled by the Customer's IT;

* Automatic deprovisioning when an SSO account is disabled;

* Stronger overall security posture for organizations with mature IdP.

## **10.4 Session lifetimes**

Session lifetimes:

* Access tokens: typically 1 hour, then refreshed using refresh tokens;

* Refresh tokens: typically 1 week, renewable on active use;

* Inactivity timeout: configurable, typically 30 days for paid Plans;

* Forced logout: triggered by password change, MFA changes, or suspected compromise.

## **10.5 Brute force protection**

To prevent credential stuffing and brute force:

* Failed login attempts are rate-limited per account and per IP;

* Repeated failures trigger increasing delays;

* Suspicious sign-in patterns (such as multiple geographic locations in short time) trigger additional verification;

* Lockouts after sustained failed attempts;

* CAPTCHA challenges where automated abuse is suspected.

## **10.6 Password reset**

Password reset:

* Initiated by email-based magic link, time-limited;

* Cannot enumerate accounts (the same success message regardless of whether the email is registered);

* Notifies the account holder of the reset event;

* Invalidates active sessions on completion.

## **10.7 No shared credentials**

Sharing of credentials between persons is prohibited under the Acceptable Use Policy. Each Authorized User must have their own account. We enforce this through:

* Authentication logging that flags concurrent sessions from different geographic locations;

* Recommendations to Customers about user-account discipline;

* Sanctions for breach as set out in the Acceptable Use Policy.

# **11\. Secure development lifecycle**

## **11.1 Security in the SDLC**

Security is integrated throughout the software development lifecycle, not added at the end. Our development practices include:

* Security requirements considered during feature design;

* Threat modelling for significant changes;

* Secure coding standards followed during implementation;

* Code review of every change, with security awareness;

* Automated security testing in continuous integration;

* Vulnerability scanning of dependencies;

* Manual security review for high-risk changes;

* Production verification after deployment.

## **11.2 Threat modelling**

For new features that touch sensitive data or change the security architecture, the team conducts threat modelling, considering:

* What we are trying to protect;

* Who might attack and what they might gain;

* What attack surface the change introduces;

* What controls mitigate the identified threats;

* What residual risk remains and whether it is acceptable.

## **11.3 Secure coding standards**

Our codebase follows standards including:

* No string-concatenated SQL — always parameterized;

* No string-interpolated HTML — always template-escaped;

* Centralised cryptographic primitives — no ad-hoc crypto;

* Centralised authentication and authorization helpers — no ad-hoc access control;

* Secret management via environment variables and secret managers — never in source control;

* No dangerous APIs without explicit security review;

* Defensive programming for inputs from untrusted sources.

## **11.4 Code review**

Every change to production code is reviewed by at least one engineer other than the author. Reviews verify:

* Functional correctness;

* Security implications;

* Performance considerations;

* Adherence to coding standards;

* Test coverage.

## **11.5 Automated testing**

Continuous integration pipelines run:

* Unit tests for business logic;

* Integration tests for cross-component behaviour;

* Static application security testing (SAST) — code-level scanners for vulnerabilities;

* Dependency vulnerability scanning;

* Container and infrastructure-as-code scanning;

* Linting for security-relevant patterns.

## **11.6 Dependency management**

Third-party dependencies:

* Are inventoried and tracked;

* Are scanned daily for known vulnerabilities;

* Are kept reasonably up to date;

* Are evaluated for trustworthiness before adoption (popularity, maintenance, license);

* Are pinned to specific versions to avoid surprise upgrades.

## **11.7 Code provenance**

To protect against supply chain attacks:

* Source code is hosted in GitHub with branch protection on the main branch;

* Production deployments come only from reviewed, merged code;

* Build artefacts are reproducible from source;

* Sub-processor SDK versions are pinned and reviewed before upgrade.

# **12\. Change management**

## **12.1 Change types**

Changes to the Service fall into categories with different review requirements:

| Change type | Review |
| :---- | :---- |
| **Routine** | Bug fixes, minor improvements: standard code review \+ automated tests. |
| **Standard** | Most feature changes: code review \+ automated tests \+ security review where relevant. |
| **High impact** | Schema changes, authentication changes, multi-tenant logic: senior engineer review \+ security review \+ deployment plan. |
| **Emergency** | Hotfixes for production issues: expedited review with documented justification; post-deployment review. |

## **12.2 Deployment process**

Production deployments:

* Originate from the main branch only;

* Are gated by passing tests and reviews;

* Use blue-green or progressive rollout where practical;

* Are monitored during and after deployment;

* Can be rolled back quickly if issues are detected.

## **12.3 Database migrations**

Database schema changes:

* Use a migration framework with up/down scripts;

* Are tested in staging against representative data;

* Are backwards compatible where possible to allow safe rollback;

* Are deployed using safe-deployment patterns (such as expand-then-contract);

* Are reviewed by senior engineers for impact on tenant isolation.

# **13\. Logging, monitoring, and detection**

## **13.1 What we log**

We capture logs across multiple layers:

* Application logs: requests, errors, authentication events, authorization decisions;

* Database logs: queries (where appropriate), changes, access control events;

* Infrastructure logs: container starts, deployments, configuration changes;

* Authentication logs: sign-ins, sign-outs, password resets, MFA events;

* Security logs: WAF blocks, rate-limit triggers, suspicious activity flags;

* Audit logs: significant Customer-facing actions (contract sent, payment recorded, user invited).

## **13.2 What we do not log**

To protect privacy, we do not routinely log:

* Full request bodies containing personal data of End Clients;

* Passwords or other credentials;

* Cardholder data;

* Cryptographic keys;

* Other sensitive content beyond what is necessary for security or operations.

## **13.3 Log retention**

Log retention varies by category:

* Operational logs (errors, performance): typically 30 days;

* Security and audit logs: typically 12 months;

* Authentication logs: typically 12 months;

* Customer-facing audit trails (such as signing audit logs): see Data Retention Policy for specific periods.

Logs are subject to the same retention and deletion rules as other Lintel data.

## **13.4 Monitoring**

Monitoring spans:

* Availability monitoring: health checks for critical components;

* Performance monitoring: latency, error rates, queue depths;

* Security monitoring: failed authentication patterns, suspicious access, anomalies;

* Capacity monitoring: storage, compute, bandwidth utilization;

* Sub-processor monitoring: status of critical Sub-processors;

* Email deliverability monitoring: bounces, complaints, blacklist signals.

## **13.5 Alerting**

Significant events trigger alerts to the on-call engineer and (depending on severity) to the broader team. Alerts are tuned to minimize false positives while ensuring real incidents are not missed.

## **13.6 Detection**

In addition to threshold-based monitoring, we employ anomaly detection for:

* Login patterns suggesting credential compromise;

* Data access patterns suggesting bulk extraction;

* Email sending patterns suggesting spam or compromised accounts;

* API usage patterns suggesting abuse or scraping;

* Configuration drift suggesting unauthorized changes.

# **14\. Vulnerability management**

## **14.1 Sources of vulnerabilities**

We identify vulnerabilities through:

* Continuous automated scanning of code, dependencies, containers, and infrastructure;

* Manual security testing during development;

* External penetration testing (engaged at intervals appropriate to our scale);

* Coordinated vulnerability disclosure programme (Section 23);

* Vendor security advisories (Sub-processors, dependencies);

* Threat intelligence feeds.

## **14.2 Severity classification**

Vulnerabilities are classified using Common Vulnerability Scoring System (CVSS) v3.1 or equivalent, into:

| Severity | CVSS score | Target remediation |
| :---- | :---- | :---- |
| Critical | 9.0 – 10.0 | Within 7 days; immediate response and possibly emergency change. |
| High | 7.0 – 8.9 | Within 30 days. |
| Medium | 4.0 – 6.9 | Within 90 days. |
| Low | 0.1 – 3.9 | Tracked and addressed in normal cadence; no specific deadline. |

## **14.3 Remediation process**

On identifying a vulnerability:

* Triage by the security or engineering team within 1 working day;

* Severity classification and target remediation date;

* Tracking in our internal vulnerability tracker;

* Remediation via standard or expedited change process;

* Verification that the remediation closes the vulnerability;

* Where customer impact is significant, notification under the Incident Response Policy.

## **14.4 Accepted risk**

In rare cases, a vulnerability may be accepted as residual risk where:

* Exploitation is not practical given other compensating controls;

* Remediation cost is disproportionate to risk;

* A vendor patch is not available and workarounds are inadequate.

Acceptance is documented with reasoning, approved by the Security Lead, and reviewed periodically.

## **14.5 Penetration testing**

Independent penetration testing is conducted at appropriate intervals (typically annually for established platforms; more frequently after material architectural change). Tests cover:

* External-facing web application;

* API endpoints;

* Authentication and authorization;

* Tenant isolation;

* Common vulnerability classes (OWASP Top 10, ASVS controls).

Findings are remediated according to severity. Summary reports are available to enterprise Customers under NDA.

# **15\. Patch management**

## **15.1 Operating systems and runtimes**

Production hosts, containers, and runtimes are patched:

* Critical security patches: within 7 days of vendor release;

* High-severity security patches: within 30 days;

* Standard patches: in normal cadence (typically monthly).

Where Sub-processors handle the underlying infrastructure (such as Supabase managing the database), we rely on their patching SLAs and monitor for advisories.

## **15.2 Dependencies**

Software dependencies are kept reasonably current:

* Critical security advisories trigger immediate upgrades;

* Routine dependency updates happen on a regular cadence (typically monthly);

* Major version upgrades follow planned migration with full testing.

## **15.3 Patch exceptions**

In limited cases we may defer patches:

* Where a patch breaks compatibility and the risk is acceptable;

* Where compensating controls mitigate the underlying risk;

* Pending coordination with Sub-processors for shared infrastructure.

Deferrals are documented and reviewed.

# **16\. Backup and disaster recovery**

## **16.1 Backup approach**

Customer Data is backed up to protect against:

* Accidental deletion or corruption by Customers;

* Software bugs causing data loss;

* Infrastructure failures;

* Malicious actions including ransomware;

* Disaster events affecting our primary infrastructure.

## **16.2 What is backed up**

We back up:

* The database (Supabase PostgreSQL): continuous point-in-time recovery plus daily snapshots;

* File storage (Supabase Storage): replicated and versioned;

* Configuration and secrets: managed in separate, hardened systems;

* Application code: source-controlled in GitHub.

## **16.3 Retention**

Backup retention:

* Point-in-time recovery: typically 7-30 days;

* Daily snapshots: typically retained for 30 days;

* Longer-term backups (monthly, yearly): subject to Plan and storage budget.

After the retention window, backups are overwritten in normal rotation. We do not actively scrub deleted data from backups; instead we maintain a deletion log so that restorations filter out data that should remain deleted (see Account Deletion Policy Section 12).

## **16.4 Geographic resilience**

Backups are stored in geographically separate regions from the primary database to protect against regional failures.

## **16.5 Restoration testing**

Backup restoration is tested:

* Routinely (using automated restore verification);

* Periodically through tabletop exercises (Incident Response Policy Section 21);

* Whenever the backup configuration is materially changed.

## **16.6 Recovery objectives**

We aim for the following recovery objectives in normal operations:

* Recovery Point Objective (RPO): less than 1 hour for the database (i.e., we expect to lose no more than the last hour of data in a worst-case restoration);

* Recovery Time Objective (RTO): less than 4 hours for the database (i.e., we expect restoration to complete within 4 hours of initiation).

Actual recovery times depend on the nature of the event and may be longer for catastrophic scenarios.

# **17\. Business continuity**

## **17.1 Continuity scenarios**

Our business continuity planning addresses scenarios including:

* Failure of a single Sub-processor;

* Regional infrastructure outages;

* Loss of key personnel;

* Office or facility unavailability;

* Natural disasters affecting our region;

* Cybersecurity incidents disrupting operations.

## **17.2 Sub-processor failure**

For critical Sub-processors, we identify:

* Workarounds in case of short-term unavailability;

* Alternative providers in case of long-term unavailability;

* Data export capability to migrate if necessary.

## **17.3 Personnel resilience**

Knowledge of critical systems is shared across multiple personnel — no single person is irreplaceable in operating the platform. Documentation, runbooks, and cross-training reduce single-person dependency.

## **17.4 Communications**

In continuity scenarios, we communicate with Customers via:

* The status page (status.getlintel.org);

* Email to active Customer addresses;

* Social media (where appropriate);

* Direct contact for the most significantly affected Customers.

## **17.5 Continuous review**

Continuity plans are reviewed annually and after material incidents.

# **18\. Endpoint security**

## **18.1 Lintel personnel devices**

Lintel personnel use devices that meet baseline security requirements:

* Full-disk encryption enabled (FileVault, BitLocker, or equivalent);

* Operating-system patches kept current;

* Endpoint protection software where appropriate to the role and OS;

* Strong device passwords or biometric authentication;

* Screen lock after short idle period;

* Backups for individual work, where appropriate.

## **18.2 Mobile devices**

Personnel mobile devices used to access Lintel systems:

* Use device passcodes;

* Enable remote wipe capability;

* Are not used for shared accounts or shared sessions.

## **18.3 Bring-your-own-device (BYOD)**

BYOD is permitted for some personnel roles, with conditions:

* Device meets the security baseline;

* Work data is segregated from personal data where reasonable;

* Personnel acknowledge that lost or compromised devices must be reported immediately.

## **18.4 Endpoint detection**

Where appropriate to the role, endpoints have detection capabilities for:

* Malware;

* Unusual network activity;

* Unauthorized software installation;

* Loss or theft.

# **19\. Physical security**

## **19.1 Data centres**

Lintel does not operate its own physical data centres. Customer Data is stored in data centres operated by our Sub-processors (Supabase via AWS, Cloudflare, etc.). These providers maintain:

* Multi-factor physical access controls;

* 24/7 staffed monitoring;

* CCTV coverage and recording;

* Environmental controls (fire suppression, HVAC, power redundancy);

* Tier III or Tier IV ratings, or equivalent;

* SOC 2 / ISO 27001 / equivalent certifications.

## **19.2 Lintel offices**

Lintel's offices (currently 27 Carter Street, Ebute Metta, Lagos) maintain physical controls including:

* Restricted access to the working area;

* Clean desk practices for sensitive materials;

* Locked storage for sensitive physical documents;

* Visitor logs and escort policies.

## **19.3 Remote work**

Many Lintel personnel work remotely. Remote work security includes:

* Use of secure, trusted networks;

* Avoiding public Wi-Fi for sensitive work, or using VPN where unavoidable;

* Avoiding sensitive work in public places where screens can be observed;

* Secure storage of devices when not in use.

# **20\. Third-party risk management**

## **20.1 Sub-processor security**

Sub-processors are required to meet our security standards. The Subprocessor Disclosure lists each Sub-processor with their certifications, processing locations, and safeguards. Key requirements include:

* Industry-recognized security certifications (SOC 2, ISO 27001);

* Encryption at rest and in transit;

* Vulnerability management and patching;

* Security incident notification obligations;

* Personnel security and training;

* Sub-processor management for their own sub-processors.

## **20.2 Due diligence**

Before engaging a Sub-processor, we assess:

* Certifications and published security documentation;

* Privacy and security practices;

* Incident history;

* Contract terms and risk allocation;

* Operational track record.

See the Subprocessor Disclosure (Section 10\) for full details.

## **20.3 Ongoing oversight**

We monitor Sub-processors continuously:

* Subscribe to their security advisory feeds;

* Review their published incident notifications;

* Review changes to their privacy and security practices;

* Conduct periodic security reviews.

## **20.4 Other third parties**

Vendors and contractors who interact with Customer Data, even occasionally, are bound by confidentiality and security obligations. Their access is scoped and time-limited where possible.

# **21\. Human resources security**

## **21.1 Background screening**

Lintel personnel with access to production systems or Customer Data undergo background screening where lawful and proportionate, which may include:

* Identity verification;

* Reference checks;

* Employment history verification;

* Criminal record checks (in jurisdictions where lawful and where the role warrants);

* Sanctions screening.

## **21.2 Confidentiality**

All personnel are bound by written confidentiality obligations covering:

* Customer Data and Customer Confidential Information;

* Lintel Confidential Information;

* Third-party Confidential Information;

* Information learned through incident response, due diligence, and audit.

Confidentiality survives employment or engagement.

## **21.3 Acceptable use of resources**

Personnel must comply with internal acceptable-use rules covering:

* Use of company devices;

* Use of credentials and access;

* Use of generative AI and external tools (no transmission of Customer Data to public models);

* Personal use of company resources;

* Conduct on social media in relation to Lintel and Customers.

## **21.4 Off-boarding**

When personnel leave Lintel:

* All system access is revoked promptly (target: within 24 hours of departure for routine departures; immediately for security-sensitive contexts);

* Devices are returned or remotely wiped;

* Confidentiality obligations continue;

* Customer-specific knowledge is transitioned to remaining team members.

## **21.5 Disciplinary processes**

Breach of security obligations may result in disciplinary action up to and including termination. Where breach involves potential criminal conduct, we may report to law enforcement.

# **22\. Security training and awareness**

## **22.1 Mandatory training**

All Lintel personnel complete annual security training covering:

* This Policy and its key requirements;

* Information classification and handling;

* Password and credential hygiene;

* Phishing recognition;

* Reporting security concerns;

* Data protection basics (NDPA, GDPR);

* Acceptable use of company resources.

## **22.2 Role-specific training**

Personnel in specialised roles receive deeper training:

* Engineers: secure development, threat modelling, common vulnerability classes;

* Operations: production access controls, change management;

* Security: forensic basics, incident handling, vulnerability management;

* Support: spotting suspicious communications, escalating security concerns;

* Legal and DPO: data protection law, regulator engagement.

## **22.3 Awareness programmes**

Beyond formal training, we maintain ongoing awareness through:

* Periodic security communications;

* Phishing simulations;

* Lessons learned from incidents (sanitized);

* Reminders during high-risk seasons (such as tax filing periods).

## **22.4 Tracking**

Training completion is tracked. Non-completion triggers reminders, escalation, and (where appropriate) suspension of system access.

# **23\. Coordinated vulnerability disclosure**

## **23.1 We welcome reports**

Lintel welcomes reports of security vulnerabilities from researchers, customers, and any member of the public who discovers a potential issue. Good-faith reports are treated favourably and reporters are not penalized.

## **23.2 How to report**

Send vulnerability reports to security@getlintel.org. Where possible, include:

* A description of the vulnerability;

* Steps to reproduce;

* Potential impact;

* Any suggested remediation;

* Your contact details (we keep your identity confidential unless you ask otherwise).

If your finding is sensitive, you can encrypt the report. We will provide a PGP key on request.

## **23.3 What you can do**

In testing, you may:

* Investigate using your own account with your own test data;

* Access only what is necessary to demonstrate the issue;

* Test against the production application at app.getlintel.org or the marketing site at getlintel.org.

## **23.4 What you must not do**

In testing, you must NOT:

* Access, modify, or exfiltrate other Customers' or End Clients' data;

* Disrupt Service availability;

* Perform automated attacks of sustained intensity (such as DDoS testing);

* Use social engineering against Lintel personnel or Customers;

* Use physical attacks on Lintel offices or Sub-processor facilities;

* Disclose the vulnerability publicly before we have had reasonable opportunity to remediate (typically 90 days from initial report);

* Use the vulnerability for any purpose other than demonstrating it to us.

## **23.5 Our commitments**

When you report in good faith and in accordance with this Section, we will:

* Acknowledge receipt within 4 working hours where possible;

* Triage and respond substantively within 5 working days;

* Keep you informed of progress on remediation;

* Coordinate disclosure timing with you;

* Not pursue legal action against you for good-faith research;

* Where appropriate, publicly acknowledge your contribution (with your consent);

* Consider rewards on a discretionary basis for high-impact findings (we do not currently operate a formal bug bounty).

## **23.6 Out of scope**

Issues that are generally out of scope:

* Reports based purely on automated scanner output without manual verification;

* Theoretical issues without exploitable impact;

* Issues affecting third-party services we use (please report those to the third party);

* Social engineering of Lintel personnel;

* Self-XSS, missing security headers without exploitable impact, lack of rate limiting on non-sensitive endpoints, and other issues commonly categorized as informational.

# **24\. Customer-side security responsibilities**

## **24.1 Shared responsibility**

Security is a shared responsibility. Lintel secures the Service infrastructure and application; Customers secure their access to it, their internal practices, and the data they upload. Failure on either side can undermine security.

## **24.2 Account security**

Customers should:

* Use strong, unique passwords for each Authorized User;

* Enable MFA wherever available;

* Avoid sharing credentials;

* Promptly revoke access for departing staff;

* Review active sessions periodically;

* Monitor account audit logs for unexpected activity.

## **24.3 Device and network security**

Customers should ensure that devices used to access Lintel are themselves secure:

* Use up-to-date operating systems and browsers;

* Use anti-malware where appropriate;

* Be cautious about public Wi-Fi;

* Lock screens when away from devices.

## **24.4 Phishing and social engineering**

Lintel personnel will never ask Customers for passwords or full payment card details. Treat any such request as suspicious. Be wary of:

* Emails appearing to come from Lintel but with unusual sender addresses;

* Urgent requests for credentials or access;

* Links to login pages that are not on getlintel.org or app.getlintel.org;

* Requests to install software not from the App Store, Google Play, or our official channels.

If in doubt, contact us through known channels rather than responding to the suspicious message.

## **24.5 Data handling within Customer organisation**

Customer organizations are responsible for their own data handling practices, including:

* Internal access controls within the agency;

* Training staff on confidentiality;

* Securing data exported from Lintel onto Customer devices or systems;

* Securely disposing of printed documents;

* Complying with the NDPA, GDPR, and other Applicable Law as data controller of End Client data.

## **24.6 Suspicious activity**

Customers should report:

* Suspected compromise of their account credentials;

* Suspicious emails purporting to come from Lintel;

* Unexpected activity in their account audit logs;

* Suspected security vulnerabilities;

* Concerns about Authorized User conduct.

Report to security@getlintel.org for security issues and abuse@getlintel.org for conduct issues. For urgent security matters, mark the subject "URGENT".

# **25\. Compliance and audit**

## **25.1 Compliance objectives**

Our security programme is designed to support compliance with:

* The Nigeria Data Protection Act 2023 (NDPA) and NDPC guidance;

* The EU General Data Protection Regulation (GDPR) and UK GDPR where applicable;

* Contractual commitments to Customers under the Terms and DPA;

* PCI-DSS requirements indirectly applicable through our payment processor;

* Industry frameworks such as SOC 2 and ISO 27001 (we operate on the basis of working towards these standards and engaging Sub-processors who hold them).

## **25.2 Customer audit rights**

Customers have audit rights under the DPA. In practice, audit is typically conducted by:

* Reviewing this Policy, the Subprocessor Disclosure, the Privacy Policy, and other published documentation;

* Requesting Sub-processor audit reports (SOC 2, ISO 27001\) under NDA where available;

* Requesting written responses to specific security questions through the procurement process;

* In exceptional cases for enterprise Customers, conducting on-site or remote audits subject to confidentiality, scope, and frequency limits set out in the DPA.

## **25.3 Regulator audit rights**

Regulators with lawful jurisdiction may audit our security practices. We cooperate with such audits.

## **25.4 Continuous compliance**

Compliance is an ongoing activity, not a point-in-time achievement. We maintain:

* Internal records of compliance assessments;

* Records of policy reviews and updates;

* Records of training completion;

* Records of audit and assessment outcomes;

* Records of incidents and remediation.

# **26\. Changes to this policy**

We may update this Policy from time to time. When we make changes:

* We will update the "Effective date" at the top of this Policy;

* For material changes (such as significant control changes affecting Customer assurances), we will give advance notice (typically 30 days) by email and in-product notice;

* For non-material changes (clarifications, internal restructure, typo corrections), the change may take effect on publication;

* Continued use of the Service after the effective date constitutes acceptance of the updated Policy.

# **27\. Contact**

For security-related enquiries:

| Purpose | Contact |
| :---- | :---- |
| **Report a suspected security incident** | security@getlintel.org |
| **Vulnerability disclosure** | security@getlintel.org |
| **Security questions or due diligence** | security@getlintel.org |
| **Privacy and data protection enquiries** | privacy@getlintel.org |
| **Data Protection Officer (DPO)** | dpo@getlintel.org |
| **Audit and compliance enquiries** | dpo@getlintel.org |
| **Legal questions about this Policy** | legal@getlintel.org |
| **General product support** | hello@getlintel.org |
| **Postal address** | Techforge Developers Limited, 27 Carter Street, Ebute Metta, Lagos, Nigeria |

We aim to acknowledge security enquiries within 4 working hours where possible, and respond substantively within 5 working days. For urgent security incidents in progress, mark your email "URGENT" in the subject line.

*End of Security Policy*

Lintel · Version 1.0 · Effective 14 June 2026 · Techforge Developers Limited · RC 8371716

*This Policy is provided as a template. We strongly recommend independent security and legal review before adopting it.*