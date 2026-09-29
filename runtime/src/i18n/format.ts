import type { Money } from '../types.js';

export function formatNumberFor(locale: string, value: number | string, options?: Intl.NumberFormatOptions): string {
  return new Intl.NumberFormat(locale, options).format(value as unknown as number);
}

export function formatMoneyFor(locale: string, money: Money): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency: money.currency }).format(
    money.amount as unknown as number
  );
}

const DATE_STYLE_MAP: Record<string, Intl.DateTimeFormatOptions['dateStyle']> = {
  short: 'short',
  medium: 'medium',
  long: 'long'
};

export function formatDateFor(locale: string, value: string | Date, style: 'short' | 'medium' | 'long' = 'medium'): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  return new Intl.DateTimeFormat(locale, { dateStyle: DATE_STYLE_MAP[style] }).format(date);
}

export function formatPercentFor(_locale: string, value: string | number): string {
  return `${value}%`;
}
