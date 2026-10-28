import { HttpError } from './error.js';

// Validates req.body against a zod schema and replaces it with the parsed result,
// so controllers only ever see clean, typed data.
export const validate = (schema) => (req, res, next) => {
  const result = schema.safeParse(req.body ?? {});
  if (!result.success) {
    const details = result.error.issues.map((i) => ({ field: i.path.join('.'), message: i.message }));
    throw new HttpError(400, 'Validation failed', details);
  }
  req.body = result.data;
  next();
};
