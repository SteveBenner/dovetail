export const FIELD_CONTEXT = Symbol('dovetail.field');

export interface FieldContextValue {
  controlId: string;
  describedBy: string | undefined;
  invalid: boolean;
  required: boolean;
}
