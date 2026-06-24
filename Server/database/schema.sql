
CREATE TABLE beta_codes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code_hash CHAR(64) NOT NULL UNIQUE,
  label VARCHAR(120) NULL,
  expires_at DATETIME NULL,
  revoked_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE installations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  beta_code_id BIGINT UNSIGNED NOT NULL,
  installation_id_hash CHAR(64) NOT NULL UNIQUE,
  token_hash CHAR(64) NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  last_seen_at DATETIME NULL,
  revoked_at DATETIME NULL,
  CONSTRAINT fk_installation_code FOREIGN KEY (beta_code_id) REFERENCES beta_codes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE scan_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  installation_id BIGINT UNSIGNED NOT NULL,
  client_version VARCHAR(32) NOT NULL,
  channel VARCHAR(16) NOT NULL,
  session_uuid CHAR(36) NOT NULL,
  windows_major TINYINT UNSIGNED NOT NULL,
  windows_build VARCHAR(32) NOT NULL,
  powershell_major TINYINT UNSIGNED NOT NULL,
  is_admin TINYINT(1) NOT NULL,
  device_type VARCHAR(32) NOT NULL,
  locale VARCHAR(24) NOT NULL,
  ram_bucket VARCHAR(32) NOT NULL,
  storage_types_json JSON NOT NULL,
  disk_count TINYINT UNSIGNED NOT NULL,
  battery_present TINYINT(1) NOT NULL,
  work_status VARCHAR(32) NOT NULL,
  finding_count SMALLINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL,
  UNIQUE KEY uq_installation_session (installation_id, session_uuid),
  KEY ix_sessions_created (created_at),
  CONSTRAINT fk_session_installation FOREIGN KEY (installation_id) REFERENCES installations(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE finding_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  scan_session_id BIGINT UNSIGNED NOT NULL,
  rule_id VARCHAR(96) NOT NULL,
  severity VARCHAR(16) NOT NULL,
  KEY ix_findings_rule (rule_id),
  CONSTRAINT fk_finding_session FOREIGN KEY (scan_session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE operation_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  scan_session_id BIGINT UNSIGNED NOT NULL,
  operation_id VARCHAR(96) NOT NULL,
  status VARCHAR(32) NOT NULL,
  error_code VARCHAR(64) NULL,
  fallback_used TINYINT(1) NOT NULL,
  KEY ix_operations_operation (operation_id),
  CONSTRAINT fk_operation_session FOREIGN KEY (scan_session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE action_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  scan_session_id BIGINT UNSIGNED NOT NULL,
  action_id VARCHAR(96) NOT NULL,
  status VARCHAR(32) NOT NULL,
  KEY ix_actions_action (action_id),
  CONSTRAINT fk_action_session FOREIGN KEY (scan_session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE feedback_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  scan_session_id BIGINT UNSIGNED NOT NULL,
  score TINYINT UNSIGNED NOT NULL,
  helped TINYINT(1) NULL,
  created_at DATETIME NOT NULL,
  UNIQUE KEY uq_feedback_session (scan_session_id),
  CONSTRAINT fk_feedback_session FOREIGN KEY (scan_session_id) REFERENCES scan_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
