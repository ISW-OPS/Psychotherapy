-- ============================================================
-- NOTIFICATIONS — per-user inbox for patients & staff
-- ============================================================

CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type TEXT DEFAULT 'system' CHECK (type IN ('appointment','order','plan','system')),
  title TEXT NOT NULL,
  body TEXT,
  link TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own notifications" ON notifications
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users update own notifications" ON notifications
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Staff insert notifications" ON notifications
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff')
    OR user_id = auth.uid()
  );

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
