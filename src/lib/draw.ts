import { supabase } from "./supabase";

/**
 * Core Draw Engine Logic
 * Handles 5-number matching, prize splitting, and jackpot rollover.
 */

export type DrawMode = "random" | "algorithmic";

/**
 * Generate 5 unique winning numbers.
 * @param mode 'random' | 'algorithmic'
 * @param allScores Optional scores for weighting in algorithmic mode
 */
export function generateWinningNumbers(mode: DrawMode, allScores: any[] = []): number[] {
  if (mode === "random") {
    const numbers: number[] = [];
    while (numbers.length < 5) {
      const num = Math.floor(Math.random() * 45) + 1;
      if (!numbers.includes(num)) numbers.push(num);
    }
    return numbers.sort((a, b) => b - a); // Sort descending (standard for top scores)
  }

  // Algorithmic Mode: Weighted based on common high scores
  // For now, take frequent top scores and add variance
  const historicalAverages = allScores.map((s) => s.stableford_points);
  const avg =
    historicalAverages.length > 0
      ? historicalAverages.reduce((a, b) => a + b, 0) /
        historicalAverages.length
      : 36; // Default to 36 (typical good score)

  const numbers: number[] = [];
  while (numbers.length < 5) {
    const variance = (Math.random() - 0.5) * 20;
    const num = Math.max(
      1,
      Math.min(45, Math.round(avg + variance)),
    );
    if (!numbers.includes(num)) numbers.push(num);
  }
  return numbers.sort((a, b) => b - a);
}

/**
 * Calculate matching numbers between entry and winning numbers.
 */
export function countMatches(entry: number[], winning: number[]): number {
  return new Set(entry.filter((num) => winning.includes(num))).size;
}

/**
 * Get the current rollover amount from the latest published draw.
 */
export async function getLatestRollover(): Promise<number> {
  const { data, error } = await supabase
    .from("draws")
    .select("jackpot_rollover_amount")
    .eq("status", "published")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return Number(data?.jackpot_rollover_amount || 0);
}

/**
 * Core Algorithm: Calculates simulation or final results.
 */
export async function calculateDrawResults(mode: DrawMode, customWinningNumbers?: number[]) {
  const { data, error } = await supabase.rpc("run_draw", { p_mode: mode, p_winning_numbers: customWinningNumbers || null, p_publish: false });
  if (error) throw error;
  return normaliseResult(data);
}

/**
 * Officially persistent a draw result.
 */
export async function finalizeAndPublishDraw(results: Awaited<ReturnType<typeof calculateDrawResults>>, mode: DrawMode) {
  const { data, error } = await supabase.rpc("run_draw", { p_mode: mode, p_winning_numbers: results.winningNumbers, p_publish: true });
  if (error) throw error;
  return normaliseResult(data);
}

function normaliseResult(data: any) {
  const result = typeof data === "string" ? JSON.parse(data) : data;
  const winners = result.winners || [];
  return { ...result, winners, allEntries: result.allEntries || [], tierBreakdown: { 5: winners.filter((w: any) => w.match_count === 5).length, 4: winners.filter((w: any) => w.match_count === 4).length, 3: winners.filter((w: any) => w.match_count === 3).length } };
}
