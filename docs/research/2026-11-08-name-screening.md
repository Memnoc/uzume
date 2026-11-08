# Distribution name screening

Date: 2026-11-08. Candidates: **Awen, Tine, Facet, Splint, Nook**.
Splint is evaluated exactly as supplied, rather than the earlier suggestion
Spindle. Status: preliminary research; no name selected or legally cleared.

## Finding

All five names already identify software products or developer tools. None is a
clean practical choice for an independent Neovim distribution. This is a naming
and discoverability judgment, not a finding that using any name would necessarily
infringe a trademark.

| Candidate | First-party evidence | Practical assessment |
| --- | --- | --- |
| Awen | [Awen's own site](https://www.awen.ai/about-us) describes an AI platform for visual creation through conversation. Its [terms](https://www.awen.ai/terms) identify Awen AI Corporation and reserve its branding rights. | Exact commercial AI product name. A different kind of editor, but an awkward association for another AI-oriented workspace. Prefer another name. |
| Tine | [Tine Code Editor](https://github.com/travisdoor/tine) is already a lightweight, keyboard-focused editor with LSP, project workspaces, and shell integration. A separate [terminal editor](https://github.com/deadpixi/tine) and [local outliner](https://tine.page/) also use Tine. [Tine groupware](https://github.com/tine-groupware/tine#licenses-copyrights-and-trademarks) explicitly claims a registered trademark in its name. | The closest direct editor collision. Drop from the shortlist. The groupware registration claim is an owner's statement; its registration, territory, and scope were not independently verified. |
| Facet | [Facet](https://facet.rs/) is an existing Rust reflection and tooling ecosystem, with [its own repository](https://github.com/facet-rs/facet). | Exact developer-tool name, particularly inconvenient if this distribution later includes a Rust component. Prefer another name. No trademark registration status established. |
| Splint | [Splint](https://splint.org/) is an established static checker for C security issues and coding mistakes; its [source repository](https://github.com/splintchecker/splint) uses the same name. | Direct developer-tool and command-name collision, including one of our supported languages. Drop from the shortlist. No trademark registration status established. |
| Nook | [Nook](https://github.com/wuruofan/nook) monitors coding-agent sessions, including Claude Code and Codex, with questions and approvals. [NookOS](https://nookos.dev/) also manages coding agents and embedded terminal sessions. Barnes & Noble's [trademark page](https://www.barnesandnoble.com/terms/trademarks) lists NOOK. | Both close workflow overlap and an established consumer technology brand. Drop from the shortlist. Barnes & Noble's statement is first-party evidence, not an independent register-status check. |

## Copyright and trademarks

The U.S. Copyright Office says names and short phrases are not protected by
copyright; sufficiently original logo artwork can be. For the name itself,
trademark conflicts are the relevant concern. This U.S. guidance is not a
worldwide legal conclusion. [Copyright Office FAQ](https://www.copyright.gov/help/faq/faq-protect.html)

The USPTO explains that confusion depends on similarity between marks and the
relationship between the goods or services. An existing use alone does not
decide the legal outcome. Its clearance guidance covers federal records, state
records, and common-law uses; checking only a domain or GitHub repository is
insufficient. [Likelihood of confusion](https://www.uspto.gov/trademarks/search/likelihood-confusion),
[comprehensive clearance searches](https://www.uspto.gov/trademarks/search/comprehensive-clearance-search-similar-trademarks)

For a finalist, the relevant territories and intended goods/services need to be
defined before a professional clearance decision. EUIPO points to TMview for
availability research; Ireland's IPOI provides its own search tools.
[EUIPO search guidance](https://www.euipo.europa.eu/en/help-centre/tm/faq-search-availability),
[IPOI search guidance](https://ipoi.gov.ie/en/types-of-ip/trade-marks/using-the-trade-mark-search-tools/)

## Scope and limits

This screen used web searches followed to official product sites and source
repositories, plus first-party trademark statements and official legal guidance.
It prioritized exact software, editor, developer-tool, and AI-workflow collisions.
It did not audit third-party code licences: we are considering names, not adopting
the other projects' implementations or artwork.

No complete, current trademark-register search was completed, and no candidate's
territorial registration status or full goods/services coverage was verified.
The EUIPO availability page returned an access error, and the Irish register
presented a CAPTCHA. Domain, package-name, and account availability were not
exhaustively checked. No result here is legal clearance or proof of infringement.

Recommendation: use the desired qualities behind these names to generate a more
distinctive shortlist, then screen those candidates before investing in artwork
or renaming the installation. Adding `nvim` alone should not be assumed to resolve
confusion; any compound needs its own assessment.
