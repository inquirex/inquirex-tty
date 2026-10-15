# Changelog

## 0.12.0 (unreleased)

Hand-written until `github_changelog_generator` regenerates this file at release. The family-wide notes are in inquirex's `INQUIREX_VERSION_LOG.md`.

- **BREAKING: results go to stdout.** `run` printed its JSON results on stderr; it now prints them on stdout, and draws every prompt, box and progress line on stderr, so `inqt run flow.rb > answers.json` captures a clean document. A caller that read the results from stderr must read stdout. `-o FILE` still writes a file (and now leaves stdout empty); `-o -` names stdout.
- **Ctrl-B goes back.** At any question after the first, Ctrl-B returns to the previous question with the earlier answer as its default (`Engine#back`, `#can_back?`, `#previous_answer` from inquirex 0.12.0). A tip line under the question names the key. Display and LLM steps in between are stepped over. Cmd-Backspace was considered and rejected: terminals do not send it to a program unless the user maps it by hand.
- **Headless runs: `run --answers FILE` and `--yes`.** Preset answers (`{step_id: value}`, JSON or YAML by extension) are fed to the engine through `Inquirex::Headless`; no prompt or renderer is built, standard input is never read, no LLM adapter is called, and the public-IP probe is skipped. `--yes` answers the remaining steps with their defaults. A required step left without an answer exits 1 and names the step on stderr.
- **Adapter selection comes from inquirex-llm.** `run` builds its LLM adapter with `Inquirex::LLM.adapter`, re-reading inquirex-llm's configuration after `.env` loads. The documented `INQUIREX_LLM_ADAPTER` / `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` order is unchanged, and the default models and limits now follow inquirex-llm's `INQUIREX_LLM_*` variables. An unknown `INQUIREX_LLM_ADAPTER` value now raises an error naming the variable instead of falling through to auto-detection.
- Step numbers in the progress line start at 1 again (the first step printed as "Step 2").
- **Requires `inquirex ~> 0.12` and `inquirex-llm ~> 0.12`.** 0.10.0 still required `~> 0.9.5` of both, so it could not be installed beside the 0.10.0 core.
- README samples use a fictional person (Alan Turing, `alan.turing@manchester.edu`), as does `examples/10_answers.json`.
- Ruby 4.1.0-preview1: the suite passes with Bundler 4.0.16; Gemfile.lock moves off Bundler 4.0.10, which fails on 4.1 with `uninitialized constant Pathname::SEPARATOR_PAT`. `spec/inquirex/tty/gemspec_spec.rb` fails when `lib/` requires a library that neither ships with the running Ruby nor is a declared runtime dependency.
- CircleCI config copied from inquirex core; `.ruby-version` pins 4.1.0-preview1.

## [v0.10.0](https://github.com/inquirex/inquirex-tty/tree/v0.10.0) (2026-08-21)

[Full Changelog](https://github.com/inquirex/inquirex-tty/compare/v0.6.0...v0.10.0)

**Merged pull requests:**

- Set the lockstep version to 0.10.0 [#12](https://github.com/inquirex/inquirex-tty/pull/12) ([kigster](https://github.com/kigster))
- Bump to 0.9.6 [#11](https://github.com/inquirex/inquirex-tty/pull/11) ([kigster](https://github.com/kigster))
- Pre-check LLM suggestions, add the inqt alias, join the 0.9.2 lockstep [#10](https://github.com/inquirex/inquirex-tty/pull/10) ([kigster](https://github.com/kigster))
- Fix CI: broken Gemfile path override, RuboCop scanning vendor/ [#9](https://github.com/inquirex/inquirex-tty/pull/9) ([kigster](https://github.com/kigster))

## [v0.6.0](https://github.com/inquirex/inquirex-tty/tree/v0.6.0) (2026-07-20)

[Full Changelog](https://github.com/inquirex/inquirex-tty/compare/v0.5.0...v0.6.0)

**Merged pull requests:**

- Document lib in YARD style to 100% coverage [#8](https://github.com/inquirex/inquirex-tty/pull/8) ([kigster](https://github.com/kigster))
- Use $stderr.puts for CLI messages, not warn [#7](https://github.com/inquirex/inquirex-tty/pull/7) ([kigster](https://github.com/kigster))

## [v0.5.0](https://github.com/inquirex/inquirex-tty/tree/v0.5.0) (2026-07-16)

[Full Changelog](https://github.com/inquirex/inquirex-tty/compare/v0.4.0...v0.5.0)

## [v0.4.0](https://github.com/inquirex/inquirex-tty/tree/v0.4.0) (2026-07-14)

[Full Changelog](https://github.com/inquirex/inquirex-tty/compare/971751bdfcbde3f1fd694cfb38d00bc3205b3e12...v0.4.0)

**Merged pull requests:**

- Raise inquirex-tty test coverage from 79% to 99% [#5](https://github.com/inquirex/inquirex-tty/pull/5) ([kigster](https://github.com/kigster))
- Update bundled dependencies [#4](https://github.com/inquirex/inquirex-tty/pull/4) ([kigster](https://github.com/kigster))
- Integrate inquirex-llm, drop inquirex-ui dep, add LLM-assisted tax example [#3](https://github.com/inquirex/inquirex-tty/pull/3) ([kigster](https://github.com/kigster))
- Add inquirex export command and shared OutputPath helper [#2](https://github.com/inquirex/inquirex-tty/pull/2) ([kigster](https://github.com/kigster))
- Simplify graph command: merge open-graph, add "both" format [#1](https://github.com/inquirex/inquirex-tty/pull/1) ([kigster](https://github.com/kigster))

\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*
