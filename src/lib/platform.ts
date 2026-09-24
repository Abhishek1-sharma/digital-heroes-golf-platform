export const SCORE_MIN = 1;
export const SCORE_MAX = 45;
export const MAX_RETAINED_SCORES = 5;
export const MIN_CHARITY_PERCENTAGE = 10;

export const PLANS = {
  monthly: {
    amount: 25,
    label: "£25",
    intervalLabel: "/ Month",
    renewalDays: 30,
  },
  yearly: {
    amount: 240,
    label: "£240",
    intervalLabel: "/ Year",
    renewalDays: 365,
  },
} as const;

export type PaidPlan = keyof typeof PLANS;
