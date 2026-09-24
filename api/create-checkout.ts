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

  const { priceId } = req.body;
  const token = req.headers.authorization?.replace("Bearer ", "");

  if (!priceId || !token) {
    return res.status(400).json({ error: "Missing price or authorization" });
  }

  try {
    const {
      data: { user },
      error: userError,
    } = await supabaseAdmin.auth.getUser(token);
    if (userError || !user)
      return res.status(401).json({ error: "Unauthorized" });

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      mode: "subscription",
      success_url: `${process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"}/dashboard/subscription?success=true`,
      cancel_url: `${process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000"}/dashboard/subscription?canceled=true`,
      customer_email: user.email,
      client_reference_id: user.id,
      metadata: {
        userId: user.id,
      },
      subscription_data: {
        metadata: {
          userId: user.id,
        },
      },
    });

    return res.status(200).json({ url: session.url });
  } catch (err: any) {
    console.error("Stripe error:", err);
    return res.status(500).json({ error: err.message });
  }
}
