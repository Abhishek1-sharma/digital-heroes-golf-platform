import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl = (import.meta as any).env.VITE_SUPABASE_URL;
const supabaseAnonKey = (import.meta as any).env.VITE_SUPABASE_ANON_KEY;
export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

let client: SupabaseClient | null = null;

try {
  if (isSupabaseConfigured) {
    client = createClient(supabaseUrl, supabaseAnonKey);
  } else {
    console.warn("Supabase URL or Anon Key is missing or empty.");
  }
} catch (error) {
  console.error("Failed to initialize Supabase client:", error);
}

export const supabase = new Proxy({} as SupabaseClient, {
  get(_target, prop) {
    if (!client) {
      const msg =
        "Supabase is not configured. Add VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY to .env.local, then restart Vite.";
      // Return a dummy function for common calls to avoid immediate crashes in some contexts,
      // but throw for actual data operations.
      if (prop === "auth" || prop === "from") {
        throw new Error(msg);
      }
      return undefined;
    }
    return (client as any)[prop];
  },
});
