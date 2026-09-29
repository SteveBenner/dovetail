interface Token {
  type: 'text' | 'arg';
  text?: string;
  name?: string;
  kind?: 'plural' | 'select';
  options?: Record<string, string>;
}

function splitTopLevel(body: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let current = '';
  for (const ch of body) {
    if (ch === '{') depth += 1;
    if (ch === '}') depth -= 1;
    if (ch === ',' && depth === 0) {
      parts.push(current);
      current = '';
    } else {
      current += ch;
    }
  }
  parts.push(current);
  return parts.map((p) => p.trim());
}

function parseOptions(body: string): Record<string, string> {
  const options: Record<string, string> = {};
  let i = 0;
  while (i < body.length) {
    while (i < body.length && /\s/.test(body[i])) i += 1;
    let key = '';
    while (i < body.length && body[i] !== '{' && !/\s/.test(body[i])) {
      key += body[i];
      i += 1;
    }
    while (i < body.length && /\s/.test(body[i])) i += 1;
    if (body[i] !== '{') break;
    i += 1;
    let depth = 1;
    let content = '';
    while (i < body.length && depth > 0) {
      if (body[i] === '{') depth += 1;
      if (body[i] === '}') {
        depth -= 1;
        if (depth === 0) {
          i += 1;
          break;
        }
      }
      content += body[i];
      i += 1;
    }
    if (key) options[key] = content;
  }
  return options;
}

function tokenize(pattern: string): Token[] {
  const tokens: Token[] = [];
  let i = 0;
  let text = '';
  while (i < pattern.length) {
    if (pattern[i] === '{') {
      if (text) {
        tokens.push({ type: 'text', text });
        text = '';
      }
      let depth = 1;
      let body = '';
      i += 1;
      while (i < pattern.length && depth > 0) {
        if (pattern[i] === '{') depth += 1;
        if (pattern[i] === '}') {
          depth -= 1;
          if (depth === 0) {
            i += 1;
            break;
          }
        }
        body += pattern[i];
        i += 1;
      }
      const parts = splitTopLevel(body);
      if (parts.length === 1) {
        tokens.push({ type: 'arg', name: parts[0] });
      } else {
        const [name, kind, ...rest] = parts;
        tokens.push({
          type: 'arg',
          name,
          kind: kind as 'plural' | 'select',
          options: parseOptions(rest.join(','))
        });
      }
    } else {
      text += pattern[i];
      i += 1;
    }
  }
  if (text) tokens.push({ type: 'text', text });
  return tokens;
}

export function formatICU(pattern: string, params: Record<string, string | number> = {}, locale = 'en-US'): string {
  const tokens = tokenize(pattern);
  let out = '';
  for (const token of tokens) {
    if (token.type === 'text') {
      out += token.text ?? '';
      continue;
    }
    const value = params[token.name ?? ''];
    if (!token.kind) {
      out += value !== undefined ? String(value) : `{${token.name}}`;
      continue;
    }
    const options = token.options ?? {};
    let branch: string | undefined;
    if (token.kind === 'plural') {
      const numeric = Number(value);
      const exact = options[`=${numeric}`];
      if (exact !== undefined) {
        branch = exact;
      } else {
        const category = new Intl.PluralRules(locale).select(numeric);
        branch = options[category] ?? options.other;
      }
      if (branch) {
        branch = branch.replace(/#/g, String(numeric));
      }
    } else {
      branch = options[String(value)] ?? options.other;
    }
    if (branch !== undefined) {
      out += formatICU(branch, params, locale);
    }
  }
  return out;
}
