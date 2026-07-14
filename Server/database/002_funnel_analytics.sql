ALTER TABLE installations MODIFY beta_code_id BIGINT UNSIGNED NULL;

CREATE TABLE IF NOT EXISTS download_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  release_version VARCHAR(32) NULL,
  channel VARCHAR(16) NULL,
  package_name VARCHAR(180) NULL,
  visitor_hash CHAR(64) NOT NULL,
  user_agent_hash CHAR(64) NULL,
  referrer_host VARCHAR(160) NULL,
  created_at DATETIME NOT NULL,
  KEY ix_downloads_created (created_at),
  KEY ix_downloads_release (release_version, channel)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS funnel_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  installation_id_hash CHAR(64) NULL,
  session_uuid CHAR(36) NULL,
  event_name VARCHAR(64) NOT NULL,
  release_version VARCHAR(32) NULL,
  client_version VARCHAR(32) NULL,
  channel VARCHAR(16) NULL,
  detail VARCHAR(120) NULL,
  created_at DATETIME NOT NULL,
  KEY ix_funnel_event (event_name),
  KEY ix_funnel_created (created_at),
  KEY ix_funnel_installation (installation_id_hash),
  KEY ix_funnel_session (session_uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
