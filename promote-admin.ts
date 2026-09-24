import { createClient } from "@supabase/supabase-js";
import dotenv from "dotenv";

dotenv.config({ path: ".env.local" });

const supabaseUrl = process.env.VITE_SUPABASE_URL!;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("Missing Supabase URL or service role key");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function promoteToAdmin() {
  const email = "simp12@gmail.com";

  console.log(`Promoting ${email} to admin...`);

  // 1. Find profile
  const { data: profile, error: findError } = await supabase
    .from("profiles")
    .select("id, email, role")
    .eq("email", email)
    .single();

  if (findError) {
    console.error("Error finding profile:", findError.message);
    return;
  }

  console.log("Found profile:", profile);

  // 2. Update role
  const { data, error: updateError } = await supabase
    .from("profiles")
    .update({ role: "admin" })
    .eq("id", profile.id)
    .select("id, email, role")
    .single();

  if (updateError) {
    console.error("Error promoting user:", updateError.message);
    return;
  }

  console.log("User promoted to admin successfully!");
  console.log("Updated profile:", data);
}

promoteToAdmin();
