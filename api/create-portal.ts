import Stripe from "stripe";
import { VercelRequest, VercelResponse } from "@vercel/node";
import { createClient } from "@supabase/supabase-js";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY as string, {
  apiVersion: "2023-10-16" as any,
});
const supabaseAdmin = createClient(
  process.env.VITE_SUPABASE_URL as string,
  process.env.SUPABASE_SERVICE_ROLE_KEY as string,
);

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const token = req.headers.authorization?.replace("Bearer ", "");

  if (!token) {
    return res.status(401).json({ error: "Missing authorization" });
  }

  try {
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user)
      return res.status(401).json({ error: "Unauthorized" });

    const { data: subscription } = await supabaseAdmin
      .from("subscriptions")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .maybeSingle();
    const customerId = subscription?.stripe_customer_id;
    if (!customerId)
      return res.status(404).json({ error: "No Stripe customer found" });

    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"}/dashboard/subscription`,
    });

    return res.status(200).json({ url: session.url });
  } catch (err: any) {
    console.error("Stripe error:", err);
    return res.status(500).json({ error: err.message });
  }
}
