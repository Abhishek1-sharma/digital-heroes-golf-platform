import React, { createContext, useContext, useEffect, useState } from "react";
import { isSupabaseConfigured, supabase } from "../../lib/supabase";
import type { User, Profile } from "../../types";

interface AuthContextType {
  user: User | null;
  profile: Profile | null;
  loading: boolean;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const withTimeout = <T,>(
  request: PromiseLike<T>,
  message: string,
  timeoutMs = 8000,
) =>
  Promise.race([
    Promise.resolve(request),
    new Promise<T>((_, reject) =>
      window.setTimeout(() => reject(new Error(message)), timeoutMs),
    ),
  ]);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({
  children,
}) => {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isSupabaseConfigured) {
      setLoading(false);
      return;
    }

    // Check active sessions and subscribe to auth changes
    const initAuth = async () => {
      try {
        const {
          data: { session },
        } = await withTimeout(
          supabase.auth.getSession(),
          "Supabase session request timed out. Check your Supabase URL and network connection.",
        );
        if (session?.user) {
          setUser(session.user as any);
          await fetchProfile(session.user.id);
        } else {
          setLoading(false);
        }
      } catch (error) {
        console.error("Error initializing auth:", error);
        setLoading(false);
      }
    };

    initAuth();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        setUser(session.user as any);
        void fetchProfile(session.user.id);
      } else {
        setUser(null);
        setProfile(null);
        setLoading(false);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const fetchProfile = async (userId: string) => {
    try {
      const { data, error } = await withTimeout(
        supabase.from("profiles").select("*").eq("id", userId).single(),
        "Profile request timed out. Check your Supabase RLS policies.",
      );

      if (error) {
        if (error.code === "PGRST116") {
          console.warn("Profile not found for user:", userId);
          setProfile({
            id: userId,
            email: "",
            full_name: "Play Golf member",
            role: "user",
            subscription_status: "inactive",
            subscription_tier: "none",
            onboarding_completed: false,
            lifetime_winnings: 0,
            total_impact: 0,
            created_at: new Date().toISOString(),
          });
          return;
        } else {
          throw error;
        }
      }
      setProfile(data);
    } catch (error) {
      console.error("Error fetching profile:", error);
    } finally {
      setLoading(false);
    }
  };

  const signOut = async () => {
    try {
      if (isSupabaseConfigured) {
        await supabase.auth.signOut();
      }
    } finally {
      // Clear local state even if the network request fails.
      setUser(null);
      setProfile(null);
      setLoading(false);
    }
  };

  const refreshProfile = async () => {
    if (user?.id) await fetchProfile(user.id);
  };

  return (
    <AuthContext.Provider
      value={{ user, profile, loading, signOut, refreshProfile }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
};
