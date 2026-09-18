import { z } from "zod";

export const BasisUnitSchema = z.enum(["g", "ml"]);
export const MealTypeSchema = z.enum(["breakfast", "lunch", "dinner", "snack", "other"]);
export const AiParseStatusSchema = z.enum([
  "processing",
  "needs_review",
  "confirmed",
  "rejected",
  "failed",
]);

export type BasisUnit = z.infer<typeof BasisUnitSchema>;
export type MealType = z.infer<typeof MealTypeSchema>;
export type AiParseStatus = z.infer<typeof AiParseStatusSchema>;

export const NutritionValuesSchema = z.object({
  energyKcal: z.number().nonnegative(),
  proteinG: z.number().nonnegative(),
  carbohydrateG: z.number().nonnegative(),
  fatG: z.number().nonnegative(),
});

export type NutritionValues = z.infer<typeof NutritionValuesSchema>;

export const NutritionGoalInputSchema = NutritionValuesSchema.extend({
  effectiveFrom: z.iso.date(),
  effectiveUntil: z.iso.date().nullable(),
}).refine(
  ({ effectiveFrom, effectiveUntil }) => effectiveUntil === null || effectiveUntil > effectiveFrom,
  { message: "effectiveUntil must be later than effectiveFrom", path: ["effectiveUntil"] },
);

export type NutritionGoalInput = z.infer<typeof NutritionGoalInputSchema>;

export const ParsedMealItemSchema = z
  .object({
    rawLabel: z.string().trim().min(1).max(300),
    interpretedName: z.string().trim().min(1).max(200),
    quantity: z.number().positive().nullable(),
    unit: z.string().trim().min(1).max(40).nullable(),
    confidence: z.number().min(0).max(1),
    needsClarification: z.boolean(),
    uncertaintyReason: z.string().trim().min(1).nullable(),
    alternatives: z.array(
      z.object({
        interpretedName: z.string().trim().min(1).max(200),
        reason: z.string().trim().min(1).max(500),
      }),
    ),
  })
  .superRefine((item, context) => {
    if ((item.quantity === null) !== (item.unit === null)) {
      context.addIssue({
        code: "custom",
        message: "quantity and unit must both be present or both be null",
        path: ["unit"],
      });
    }

    if (item.needsClarification && item.uncertaintyReason === null) {
      context.addIssue({
        code: "custom",
        message: "uncertaintyReason is required when clarification is needed",
        path: ["uncertaintyReason"],
      });
    }
  });

export type ParsedMealItem = z.infer<typeof ParsedMealItemSchema>;

export interface ConfirmedMealItemSnapshot extends NutritionValues {
  foodId: string | null;
  displayName: string;
  enteredQuantity: number;
  enteredUnit: string;
  canonicalQuantity: number;
  canonicalUnit: BasisUnit;
}
