# Jenkins Ops Notes

### Jenkins HTML Scraping (CI status)
- Prefer `pandoc` over ad-hoc scripts when converting Jenkins HTML to text.
- For quick plain text without images or styling, pipe through `pandoc -f html -t plain`:
```sh
curl -s "http://jenkins.example/job/.../" | pandoc -f html -t plain
```
- To keep minimal Markdown while stripping raw HTML, use an inline Lua filter that drops images/divs:
```sh
curl -s "http://jenkins.example/job/.../" \
  | pandoc -f html -t markdown_strict --wrap=none --strip-comments \
    --lua-filter=<(cat <<'LUA'
function Image(_) return {} end
function RawInline(_) return {} end
function RawBlock(_) return {} end
function Div(el) return el.content end
function Span(el) return el.content end
function Link(el)
if #el.content == 0 then return {} end
return el.content
end
LUA
)
```
- Both commands avoid embedding base64 image blobs and keep the output small for the CLI context window.

### Jenkins Logs Workflow
- Start with the standard console page (`.../console`) before downloading `consoleText`; it is usually smaller and already structured.
- If you need the full `consoleText`, download it to `/tmp` first (e.g. `curl -s .../consoleText -o /tmp/<job>.log`) before grepping, because these files can be very large.
- Once saved, explore using tools like `rg`, `sed`, or custom summarizers so the CLI context doesn’t balloon.
- Use `pandoc` (with the Lua filter above or `-t plain`) to reduce `console` output to structured text when sharing snippets.
- For additional structure, consider piping through `pandoc -t plain` or `pandoc -t markdown_strict` plus Lua filters to strip noise before analysis.
