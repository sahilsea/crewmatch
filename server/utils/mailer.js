import nodemailer from 'nodemailer';

// Sends email through SMTP_URL (e.g. smtps://user:pass@smtp.gmail.com:465).
// Without it — local development and the demo — the message is printed in the
// server's terminal instead, and the app shows the code on screen.
let transport = null;
const FROM = process.env.MAIL_FROM || 'CrewMatch <no-reply@crewmatch.dev>';

export const canSendEmail = () => Boolean(process.env.SMTP_URL);

export async function sendMail({ to, subject, text }) {
  if (!canSendEmail()) {
    if (process.env.NODE_ENV !== 'test') console.log(`\n✉️  Email to ${to}: ${subject}\n${text}\n`);
    return;
  }
  transport ??= nodemailer.createTransport(process.env.SMTP_URL);
  await transport.sendMail({ from: FROM, to, subject, text });
}
