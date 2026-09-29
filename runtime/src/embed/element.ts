import { mount, unmount, flushSync } from 'svelte';
import type { Component } from 'svelte';
import { runtime, hostEvent } from '../shell/state.svelte.js';
import { dispatchRouteChange } from '../seams/navigation/index.js';
import type { HostOptions } from '../types.js';

let mounted: HTMLElement | null = null;
let warned = false;

function readOptions(element: HTMLElement): HostOptions {
  const options: HostOptions = {
    theme: element.getAttribute('theme') ?? undefined,
    locale: element.getAttribute('locale') ?? undefined,
    routing: element.getAttribute('routing') === 'history' ? 'history' : 'memory',
    path: element.getAttribute('path') ?? '/'
  };
  const apiBase = element.getAttribute('api-base');
  if (apiBase !== null) options.apiBase = apiBase;
  const policy = element.getAttribute('version-policy');
  if (policy === 'strict' || policy === 'tolerant') options.versionPolicy = policy;
  const prefetch = element.getAttribute('prefetch');
  if (prefetch !== null) options.prefetch = prefetch !== 'false';
  return options;
}

export function defineDovetailApp(tag: string, App: Component<any>, css: string): void {
  if (customElements.get(tag)) return;

  class DovetailElement extends HTMLElement {
    static observedAttributes = ['theme', 'locale', 'path'];
    private app: Record<string, unknown> | null = null;

    connectedCallback(): void {
      if (mounted && mounted !== this) {
        if (!warned) {
          warned = true;
          console.error(`D-RUN-007 only one <${tag}> may be mounted at a time`);
        }
        return;
      }
      if (mounted === this) return;
      const shadow = this.shadowRoot ?? this.attachShadow({ mode: 'open' });
      shadow.replaceChildren();
      const style = document.createElement('style');
      style.textContent = `:host { display: block; }${css}`;
      shadow.append(style);
      const target = document.createElement('div');
      shadow.append(target);
      runtime.root = shadow;
      runtime.hostElement = this;
      runtime.hostOptions = readOptions(this);
      this.app = mount(App, { target });
      flushSync();
      mounted = this;
      hostEvent('dovetail-ready', {});
    }

    disconnectedCallback(): void {
      if (mounted !== this) return;
      if (this.app) unmount(this.app);
      this.app = null;
      flushSync();
      mounted = null;
      runtime.root = document;
      runtime.hostElement = null;
      runtime.hostOptions = null;
      this.shadowRoot?.replaceChildren();
    }

    attributeChangedCallback(name: string, oldValue: string | null, value: string | null): void {
      if (mounted !== this || oldValue === value) return;
      if (name === 'theme') {
        const next = runtime.registry?.themes.find((t) => t.id === value);
        if (next) runtime.theme = next;
      } else if (name === 'locale') {
        runtime.locale = value ?? 'en-US';
      } else if (name === 'path') {
        if (runtime.location.mode === 'memory') {
          runtime.location.push(value ?? '/');
          dispatchRouteChange();
        }
      }
    }
  }

  customElements.define(tag, DovetailElement);
}
