-- CreateTable
CREATE TABLE IF NOT EXISTS "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" TEXT,
    "display_name" TEXT NOT NULL,
    "password_hash" TEXT,
    "apple_sub" TEXT,
    "partner_name" TEXT,
    "timezone" TEXT,
    "pair_id" UUID,
    "partner_id" UUID,
    "onboarding_completed" BOOLEAN NOT NULL DEFAULT false,
    "profile_image_url" TEXT,
    "apns_token" TEXT,
    "refresh_token" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "pairs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_a" UUID NOT NULL,
    "user_b" UUID,
    "invite_code" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "anniversary" DATE,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pairs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "vault_facts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "pair_id" UUID NOT NULL,
    "category" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "added_by" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vault_facts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "shared_lists" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "pair_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "emoji" TEXT NOT NULL,
    "subtitle" TEXT,
    "created_by" UUID NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shared_lists_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "list_items" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "list_id" UUID NOT NULL,
    "pair_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "image_url" TEXT,
    "added_by" UUID NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'suggested',
    "completion_note" TEXT,
    "metadata_tmdb_id" INTEGER,
    "metadata_year" TEXT,
    "metadata_genre" TEXT,
    "metadata_rating" DOUBLE PRECISION,
    "metadata_runtime" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "list_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "swipe_sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "pair_id" UUID NOT NULL,
    "list_id" UUID NOT NULL,
    "item_ids" TEXT[] NOT NULL,
    "swipes_a" JSONB NOT NULL DEFAULT '{}',
    "swipes_b" JSONB NOT NULL DEFAULT '{}',
    "matches" TEXT[] NOT NULL DEFAULT '{}',
    "status" TEXT NOT NULL DEFAULT 'active',
    "started_by" UUID NOT NULL,
    "chosen_item_id" UUID,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ,

    CONSTRAINT "swipe_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "availability_slots" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "pair_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "start_time" TEXT,
    "end_time" TEXT,
    "label" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "availability_slots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "calendar_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "pair_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,
    "start_time" TEXT,
    "end_time" TEXT,
    "created_by" UUID NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "decline_reason" TEXT,
    "responded_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "calendar_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "significant_dates" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "pair_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "date" DATE NOT NULL,
    "emoji" TEXT,
    "recurring" BOOLEAN NOT NULL DEFAULT false,
    "added_by" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "significant_dates_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "users_email_key" ON "users"("email");
CREATE UNIQUE INDEX IF NOT EXISTS "users_apple_sub_key" ON "users"("apple_sub");
CREATE UNIQUE INDEX IF NOT EXISTS "users_partner_id_key" ON "users"("partner_id");
CREATE UNIQUE INDEX IF NOT EXISTS "pairs_invite_code_key" ON "pairs"("invite_code");
CREATE UNIQUE INDEX IF NOT EXISTS "availability_slots_pair_id_user_id_date_key" ON "availability_slots"("pair_id", "user_id", "date");

-- CreateIndex (performance)
CREATE INDEX IF NOT EXISTS "idx_pairs_invite_code" ON "pairs"("invite_code");
CREATE INDEX IF NOT EXISTS "idx_vault_facts_pair" ON "vault_facts"("pair_id");
CREATE INDEX IF NOT EXISTS "idx_list_items_list" ON "list_items"("list_id");
CREATE INDEX IF NOT EXISTS "idx_list_items_pair" ON "list_items"("pair_id");
CREATE INDEX IF NOT EXISTS "idx_swipe_sessions_pair_status" ON "swipe_sessions"("pair_id", "status");
CREATE INDEX IF NOT EXISTS "idx_availability_pair_date" ON "availability_slots"("pair_id", "date");
CREATE INDEX IF NOT EXISTS "idx_calendar_events_pair" ON "calendar_events"("pair_id");
CREATE INDEX IF NOT EXISTS "idx_significant_dates_pair" ON "significant_dates"("pair_id");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "users" ADD CONSTRAINT "users_partner_id_fkey" FOREIGN KEY ("partner_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "pairs" ADD CONSTRAINT "pairs_user_a_fkey" FOREIGN KEY ("user_a") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "pairs" ADD CONSTRAINT "pairs_user_b_fkey" FOREIGN KEY ("user_b") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "vault_facts" ADD CONSTRAINT "vault_facts_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "vault_facts" ADD CONSTRAINT "vault_facts_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "shared_lists" ADD CONSTRAINT "shared_lists_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "shared_lists" ADD CONSTRAINT "shared_lists_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "list_items" ADD CONSTRAINT "list_items_list_id_fkey" FOREIGN KEY ("list_id") REFERENCES "shared_lists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "list_items" ADD CONSTRAINT "list_items_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "list_items" ADD CONSTRAINT "list_items_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "swipe_sessions" ADD CONSTRAINT "swipe_sessions_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "swipe_sessions" ADD CONSTRAINT "swipe_sessions_started_by_fkey" FOREIGN KEY ("started_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "availability_slots" ADD CONSTRAINT "availability_slots_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "availability_slots" ADD CONSTRAINT "availability_slots_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "significant_dates" ADD CONSTRAINT "significant_dates_pair_id_fkey" FOREIGN KEY ("pair_id") REFERENCES "pairs"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "significant_dates" ADD CONSTRAINT "significant_dates_added_by_fkey" FOREIGN KEY ("added_by") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
