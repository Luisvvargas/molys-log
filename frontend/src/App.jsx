import { useEffect, useState } from 'react';

// Public API base URL injected at build time (not a secret).
const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '';

export default function App() {
  const [health, setHealth] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`${API_BASE}/api/health`)
      .then((r) => r.json())
      .then(setHealth)
      .catch((e) => setError(e.message));
  }, []);

  return (
    <main style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 640, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>Moly's Log</h1>
      <p>Pet medical history organizer — infrastructure boilerplate.</p>
      <h2>API health</h2>
      {error && <p role="alert">API unreachable: {error}</p>}
      {!error && !health && <p>Checking…</p>}
      {health && (
        <ul>
          <li>Status: <strong>{health.status}</strong></li>
          {Object.entries(health.checks).map(([name, ok]) => (
            <li key={name}>
              {name}: {ok ? '✅' : '❌'}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
