// Zugangsdaten aus Supabase: Project Settings → API (bzw. "Data API" / "API Keys").
// Der "anon"/"publishable" Key ist öffentlich und darf hier stehen –
// die Zugriffsregeln in supabase/schema.sql schützen die Daten.
// NIEMALS den "service_role"/"secret" Key hier eintragen!
window.WT_CONFIG = {
  url: "",      // z. B. "https://abcdefgh.supabase.co"
  anonKey: ""   // beginnt mit "eyJ..." oder "sb_publishable_..."
};
