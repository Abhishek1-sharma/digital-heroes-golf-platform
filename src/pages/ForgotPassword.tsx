import React from "react";
import { Link } from "react-router-dom";
import { ArrowLeft, CheckCircle2, KeyRound, Loader2, Mail } from "lucide-react";
import { supabase } from "../lib/supabase";
import { usePageTitle } from "../hooks/usePageTitle";

const ForgotPassword: React.FC = () => {
  usePageTitle("Reset access");
  const [email, setEmail] = React.useState("");
  const [password, setPassword] = React.useState("");
  const [isRecovery, setIsRecovery] = React.useState(false);
  const [sent, setSent] = React.useState(false);
  const [message, setMessage] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(false);

  React.useEffect(() => {
    const handleRecovery = () => {
      setIsRecovery(window.location.hash.includes("type=recovery"));
    };
    handleRecovery();
    window.addEventListener("hashchange", handleRecovery);
    return () => window.removeEventListener("hashchange", handleRecovery);
  }, []);

  const requestReset = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setMessage(null);
    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/forgot-password`,
      });
      if (error) throw error;
      setSent(true);
    } catch (error: any) {
      setMessage(error.message || "Unable to send reset instructions.");
    } finally {
      setLoading(false);
    }
  };

  const updatePassword = async (event: React.FormEvent) => {
    event.preventDefault();
    setLoading(true);
    setMessage(null);
    try {
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw error;
      setMessage("Your password has been updated. You can now sign in.");
      setIsRecovery(false);
      window.history.replaceState({}, document.title, "/forgot-password");
    } catch (error: any) {
      setMessage(error.message || "Unable to update password.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="min-h-screen bg-background px-6 pb-24 pt-36">
      <div className="mx-auto max-w-xl">
        <Link
          to="/login"
          className="mb-12 inline-flex items-center gap-3 text-xs font-bold uppercase tracking-widest text-on-surface-variant hover:text-primary"
        >
          <ArrowLeft className="h-4 w-4" /> Back to login
        </Link>
        <section className="glass-card p-8 md:p-12">
          <div className="mb-8 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
            {isRecovery ? (
              <KeyRound className="h-6 w-6" />
            ) : (
              <Mail className="h-6 w-6" />
            )}
          </div>
          <h1 className="mb-4 font-display text-4xl font-black uppercase">
            {isRecovery ? "Set a new key" : "Reset access"}
          </h1>
          <p className="mb-10 leading-relaxed text-on-surface-variant">
            {isRecovery
              ? "Choose a new password for your Play Golf account."
              : "We will send a secure reset link to the email attached to your account."}
          </p>

          {message && (
            <div className="mb-6 rounded-xl border border-secondary/30 bg-secondary/10 p-4 text-sm text-secondary">
              {message}
            </div>
          )}
          {sent && !isRecovery ? (
            <div className="flex items-center gap-3 rounded-xl border border-primary/30 bg-primary/10 p-4 text-sm text-primary">
              <CheckCircle2 className="h-5 w-5" /> Check your inbox for the
              reset link.
            </div>
          ) : isRecovery ? (
            <form onSubmit={updatePassword} className="space-y-5">
              <input
                required
                minLength={6}
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                placeholder="New password"
                className="w-full rounded-xl border border-white/10 bg-surface-container-low px-5 py-4 outline-none focus:border-primary"
              />
              <button
                disabled={loading}
                className="flex w-full items-center justify-center gap-3 rounded-xl bg-primary px-5 py-4 text-xs font-bold uppercase tracking-widest text-background disabled:opacity-50"
              >
                {loading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  "Update password"
                )}
              </button>
            </form>
          ) : (
            <form onSubmit={requestReset} className="space-y-5">
              <input
                required
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="you@example.com"
                className="w-full rounded-xl border border-white/10 bg-surface-container-low px-5 py-4 outline-none focus:border-primary"
              />
              <button
                disabled={loading}
                className="flex w-full items-center justify-center gap-3 rounded-xl bg-primary px-5 py-4 text-xs font-bold uppercase tracking-widest text-background disabled:opacity-50"
              >
                {loading ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  "Send reset link"
                )}
              </button>
            </form>
          )}
        </section>
      </div>
    </main>
  );
};

export default ForgotPassword;
