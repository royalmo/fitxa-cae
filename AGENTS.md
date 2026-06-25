# Project Instructions

- Build this as a conventional Rails app first: Rails routes, controllers, ERB views, partials, helpers, sessions, Active Record, Hotwire, Propshaft, and Rails generators.
- Use Rails commands for scaffolding framework-owned files such as controllers, migrations, models, jobs, mailers, and installers.
- Keep the employee frontend at `/` and employee subpaths. Keep the manager frontend under `/admin`.
- Employee and manager authentication are separate concepts. Use separate session keys and separate model boundaries when persistence is introduced.
- Default UI language is Catalan. Keep copy ready for Rails I18n, but do not add a language selector until the product needs one.
- Prefer small, clear files. No file should grow past 1,000 lines.
- Avoid code duplication through Rails partials, helpers, concerns, scopes, and model methods when they remove real repetition.
- Do not add abstractions for one-off code.
- Keep the employee UI very simple and mobile/PWA-friendly. Keep the manager UI simple, dense, and operational.
- Do not cache `/admin` pages in the service worker.
