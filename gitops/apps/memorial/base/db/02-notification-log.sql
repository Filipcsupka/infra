-- Migration 002: notification_log table
-- Tracks all outgoing notifications per gallery (multi-stage renewal reminders, expiry notices, etc.)
-- Replaces the single renewalReminderSentAt flag with a proper log.

CREATE TABLE IF NOT EXISTS notification_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  gallery_id UUID NOT NULL REFERENCES galleries(id) ON DELETE CASCADE,
  type VARCHAR(100) NOT NULL,
  customer_email VARCHAR(255) NOT NULL,
  sent_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_log_gallery_type ON notification_log(gallery_id, type);
