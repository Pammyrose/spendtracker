import { z } from 'zod';

export const credentials = z.object({ email: z.string().trim().toLowerCase().email().max(254), password: z.string().min(8).max(128) }).strict();
const accountName = z.string().trim().min(1).max(80).regex(/^[^\u0000-\u001f\u007f]+$/).transform(value => value.replace(/\s+/g, ' '));
export const registration = credentials.extend({ name: accountName });
export const profileUpdate = z.object({ name: accountName }).strict();
const name = z.string().trim().min(1).max(10000);
const amount = z.number().finite().min(0.01).max(999999999);
const date = z.string().max(40).regex(/^(20\d{2}|2100)-\d{2}-\d{2}T/).refine(value => Number.isFinite(Date.parse(value)));
const index = z.number().int().min(0).max(199);
const reminderTimes = ['On due date', ...Array.from({ length: 31 }, (_, i) => `${i + 1} ${i === 0 ? 'day' : 'days'} before`)];
const iconIds = ['internet', 'electricity', 'water', 'streaming', 'phone', 'rent', 'food', 'social', 'pets', 'transport', 'culture', 'household', 'apparel', 'beauty', 'health', 'education', 'gift', 'other', 'shopping', 'salary', 'freelance', 'parttime', 'bonus', 'bills', 'travel', 'car', 'fuel', 'groceries', 'coffee', 'fitness', 'insurance', 'savings', 'baby', 'games', 'music', 'subscriptions'];
const catalog = z.array(z.object({ name, icon: z.enum(iconIds), color: z.number().int().min(0).max(0xffffffff) }).strict()).min(1).max(200);
const repeat = z.enum(['Daily', 'Every 2 days', 'Weekly', 'Once']);
export const backupSchema = z.object({
  version: z.literal(1),
  expenses: z.array(z.object({ title: name, category: index, amount, date }).strict()).max(100000),
  incomes: z.array(z.object({ name, category: index, amount, date, notes: z.string().max(10000).optional() }).strict()).max(100000),
  bills: z.array(z.object({ name, amount, due: date, icon: z.number().int().min(0).max(35), category: index.nullable().optional(), repeat: z.enum(['Never', 'Weekly', 'Monthly', 'Yearly']), reminder: z.enum(['Never', ...reminderTimes]), paid: z.boolean(), notes: z.string().max(1000).optional(), paymentReason: z.string().max(500).optional(), paymentPlanAt: date.nullable().optional(), paymentPlanAtMillis: z.number().int().nonnegative().nullable().optional(), followUpRepeat: repeat.optional() }).strict()).max(100000),
  settings: z.object({
    currency: z.enum(['PHP', 'USD', 'EUR']), theme: z.enum(['White', 'Pink', 'Lavender', 'Teal', 'Blue', 'Amber', 'Black', 'Brown', 'Custom']),
    customColor: z.number().int().min(0).max(0xffffffff).optional(), customDark: z.boolean().optional(),
    notificationsEnabled: z.boolean(), billReminders: z.boolean(), incomeReminders: z.boolean(), expenseAlerts: z.boolean(), monthlySummary: z.boolean(),
    billReminderTime: z.enum(reminderTimes), incomeReminderTime: z.enum(reminderTimes), expenseAlertAmount: amount,
  }).strict(),
  categories: z.object({ expense: catalog, income: catalog, bill: catalog }).strict().optional(),
  transactionActivity: z.array(z.object({ kind: z.enum(['expenseAdded', 'incomeAdded', 'incomeUpdated', 'incomeDeleted', 'billPaid', 'billUnpaid']), name, amount, recordedAt: date, transactionDate: date }).strict()).max(200).optional(),
}).strict().superRefine((data, ctx) => {
  for (const [records, kind, fallback] of [[data.expenses, 'expense', 15], [data.incomes, 'income', 5], [data.bills, 'bill', 6]]) {
    const count = data.categories?.[kind].length ?? fallback;
    if (records.some(record => record.category != null && record.category >= count)) ctx.addIssue({ code: 'custom', message: 'Category does not exist.' });
  }
  if (data.bills.some(bill => bill.paymentPlanAt && !bill.paymentReason?.trim())) ctx.addIssue({ code: 'custom', message: 'Payment plans require a reason.' });
});
export const uploadSchema = z.object({ revision: z.number().int().nonnegative().max(4294967294), data: backupSchema }).strict();
