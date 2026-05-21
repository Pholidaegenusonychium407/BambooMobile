import raw from '../assets/hms_errors.json';

export interface HmsEntry {
  description: string;
  printers: string[];
}

interface RawVariant {
  message: string;
  codes: string[];
  printers: string[];
}

// The JSON is already keyed by HMS code — direct O(1) lookup, no build step.
const data = raw as Record<string, RawVariant[]>;

// Maps the 3-char Bambu Lab serial prefix to a model name used in hms_errors.json.
// Prefixes sourced from OpenBambuAPI community documentation.
export function serialToModel(serial: string): string {
  if (!serial || serial.length < 3) return '';
  const serialCode = serial.slice(0, 3).toUpperCase();
  if (serialCode === '31B') return 'H2C';
  else if (serialCode === '094') return 'H2D';
  else if (serialCode === '239') return 'H2D Pro';
  else if (serialCode === '093') return 'H2S';
  else if (serialCode === '00M') return 'X1C';
  else if (serialCode === '03W') return 'X1E';
  else if (serialCode === '20P') return 'X2D';
  else if (serialCode === '01P') return 'P1S';
  else if (serialCode === '01S') return 'P1P';
  else if (serialCode === '22E') return 'P2S';
  else if (serialCode === '039') return 'A1';
  else if (serialCode === '030') return 'A1 Mini';
  return '';
}

// Returns the variant whose printer list includes `model`.
// Falls back to the variant covering the most printers when no match is found.
export function lookupHmsForModel(
  code: string,
  model: string,
): HmsEntry | null {
  const variants = data[`HMS_${code}`];
  if (!variants || variants.length === 0) return null;

  let best =
    model ?
      (variants.find((v) => v.printers.includes(model)) ??
      variants.reduce((a, b) =>
        b.printers.length > a.printers.length ? b : a,
      ))
    : variants.reduce((a, b) =>
        b.printers.length > a.printers.length ? b : a,
      );

  return { description: best.message, printers: best.printers };
}

export function lookupHms(code: string): HmsEntry | null {
  return lookupHmsForModel(code, '');
}

// Returns the human-readable description for an HMS error code.
// Pass the printer's serial number to get the model-specific message when
// the same code has different meanings on different printers (e.g. H2D dual-head).
export function hmsDescription(code: string, serial?: string): string {
  const model = serial ? serialToModel(serial) : '';
  const entry = lookupHmsForModel(code, model);
  return entry?.description ?? `Unknown error (${code})`;
}
