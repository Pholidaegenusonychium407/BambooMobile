import { hmsDescription, lookupHmsForModel, serialToModel } from '../utils/hmsErrors';

interface Props {
  codes: string[];
  serial?: string;
  onDismiss: () => void;
}

export default function ErrorPopup({ codes, serial, onDismiss }: Props) {
  if (codes.length === 0) return null;

  const model = serial ? serialToModel(serial) : '';

  return (
    <div className='fixed inset-0 z-50 flex items-end justify-center p-4 pb-8'>
      <div
        className='absolute inset-0 bg-black/60 backdrop-blur-sm'
        onClick={onDismiss}
      />
      <div className='relative w-full max-w-md bg-zinc-900 border border-red-700 rounded-2xl overflow-hidden shadow-2xl'>
        <div className='flex items-center gap-3 px-4 py-3 bg-red-950 border-b border-red-800'>
          <svg className='w-5 h-5 text-red-400 shrink-0' fill='none' viewBox='0 0 24 24' stroke='currentColor' strokeWidth={2}>
            <path strokeLinecap='round' strokeLinejoin='round' d='M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z' />
          </svg>
          <span className='text-red-300 font-semibold text-sm'>
            Printer Alert{codes.length > 1 ? `s (${codes.length})` : ''}
          </span>
          {model && (
            <span className='ml-auto text-red-600 text-xs font-mono'>{model}</span>
          )}
        </div>

        <div className='flex flex-col divide-y divide-zinc-800'>
          {codes.map((code) => {
            const entry = lookupHmsForModel(code, model);
            return (
              <div key={code} className='px-4 py-3 flex flex-col gap-1'>
                <p className='text-white text-sm leading-snug'>
                  {hmsDescription(code, serial)}
                </p>
                {entry?.printers.length ? (
                  <p className='text-zinc-500 text-xs'>
                    Affects: {entry.printers.join(', ')}
                  </p>
                ) : null}
                <p className='text-zinc-600 text-xs font-mono'>{code}</p>
              </div>
            );
          })}
        </div>

        <div className='px-4 py-3 border-t border-zinc-800'>
          <button
            onClick={onDismiss}
            className='w-full bg-zinc-700 hover:bg-zinc-600 active:bg-zinc-500 text-white text-sm font-medium py-2 rounded-xl transition-colors'>
            Dismiss
          </button>
        </div>
      </div>
    </div>
  );
}
