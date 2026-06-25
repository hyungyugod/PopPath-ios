# Notion Publish Checklist

The Notion connector currently needs re-authentication before pages can be created from Codex.

After Notion access is restored:

1. Create a public page titled `PopPath Privacy Policy`.
2. Paste the contents of `privacy-policy.md`.
3. Replace `{{SUPPORT_EMAIL}}` with the real support email.
4. Publish the page to the web and copy the public URL.
5. Create a public page titled `PopPath Support`.
6. Paste the contents of `support.md`.
7. Replace `{{SUPPORT_EMAIL}}` with the real support email.
8. Publish the page to the web and copy the public URL.
9. Put the two public URLs into `app-store-connect-fields.md` and App Store Connect.

App Store Connect requires a publicly accessible privacy policy URL for iOS apps. The support URL should also be publicly accessible because reviewers and users can open it from the App Store product page.
