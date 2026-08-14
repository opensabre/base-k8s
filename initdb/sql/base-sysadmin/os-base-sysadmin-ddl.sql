SET NAMES utf8;
USE os_base_sysadmin;
-- 审计日志表
DROP TABLE IF EXISTS base_sys_audit_log;
CREATE TABLE IF NOT EXISTS `base_sys_audit_log` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `operation_type` varchar(50) NOT NULL COMMENT '操作类型',
    `operation_time` datetime NOT NULL COMMENT '操作时间',
    `operator_username` varchar(100) NOT NULL COMMENT '操作人用户名',
    `module` varchar(100) NOT NULL COMMENT '操作模块',
    `description` varchar(500) COMMENT '操作描述',
    `client_ip` varchar(50) COMMENT '操作IP地址',
    `target_key` varchar(50) COMMENT '操作目标关键key',
    `user_agent` varchar(500) COMMENT '用户代理',
    `request_method` varchar(10) COMMENT '请求方法',
    `request_url` varchar(500) COMMENT '请求URL',
    `request` text COMMENT '请求参数',
    `response` text COMMENT '操作结果',
    `error_message` text COMMENT '错误信息',
    `execution_time` bigint COMMENT '执行时间(毫秒)',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_operator_username` (`operator_username`),
    KEY `idx_operation_time` (`operation_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='审计日志表';

DROP TABLE IF EXISTS base_sys_captcha_scene;
CREATE TABLE IF NOT EXISTS `base_sys_captcha_scene` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `scene_code` varchar(64) NOT NULL COMMENT '场景编码',
    `scene_name` varchar(128) NOT NULL COMMENT '场景名称',
    `captcha_type` varchar(32) NOT NULL COMMENT '验证码类型',
    `template_code` varchar(64) DEFAULT NULL COMMENT '消息模板编码',
    `notification_template_id` varchar(64) DEFAULT NULL COMMENT '通知模板ID',
    `description` varchar(255) DEFAULT NULL COMMENT '描述',
    `captcha_length` int NOT NULL DEFAULT 4 COMMENT '验证码长度',
    `captcha_expire_time` int NOT NULL DEFAULT 300 COMMENT '过期时间(秒)',
    `captcha_attempts` int NOT NULL DEFAULT 3 COMMENT '最大尝试次数',
    `min_interval` int NOT NULL DEFAULT 60 COMMENT '最小间隔(秒)',
    `max_limit_count` int NOT NULL DEFAULT 100 COMMENT '单用户生成限制次数',
    `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_scene_code` (`scene_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='验证码场景表';

DROP TABLE IF EXISTS base_sys_ratelimit_scene;
CREATE TABLE IF NOT EXISTS `base_sys_ratelimit_scene` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `scene_code` varchar(64) NOT NULL COMMENT '场景编码',
    `scene_name` varchar(128) NOT NULL COMMENT '场景名称',
    `algorithm` varchar(32) NOT NULL COMMENT '限次算法',
    `dimensions` varchar(255) DEFAULT NULL COMMENT '维度代码，逗号分隔',
    `key_prefix` varchar(100) DEFAULT NULL COMMENT '业务前缀',
    `max_count` int NOT NULL DEFAULT 5 COMMENT '最大次数',
    `period` int NOT NULL DEFAULT 60 COMMENT '时间窗口(秒)',
    `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
    `description` varchar(255) DEFAULT NULL COMMENT '描述',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_scene_code` (`scene_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='限次场景表';

DROP TABLE IF EXISTS base_sys_notification_record;
DROP TABLE IF EXISTS base_sys_notification_template;
DROP TABLE IF EXISTS base_sys_notification_scene;
CREATE TABLE IF NOT EXISTS `base_sys_notification_scene` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `scene_code` varchar(64) NOT NULL COMMENT '场景编码',
    `scene_name` varchar(128) NOT NULL COMMENT '场景名称',
    `description` varchar(255) DEFAULT NULL COMMENT '描述',
    `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_scene_code` (`scene_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知场景表';

CREATE TABLE IF NOT EXISTS `base_sys_notification_template` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `scene_code` varchar(64) NOT NULL COMMENT '场景编码',
    `channel` varchar(32) NOT NULL COMMENT '发送渠道',
    `template_name` varchar(128) NOT NULL COMMENT '模板名称',
    `title` varchar(255) DEFAULT NULL COMMENT '标题',
    `content` text NOT NULL COMMENT '模板内容',
    `param_schema` varchar(1000) DEFAULT NULL COMMENT '参数说明',
    `sort` int NOT NULL DEFAULT 1 COMMENT '排序',
    `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否启用',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_scene_channel` (`scene_code`, `channel`),
    KEY `idx_scene_enabled_sort` (`scene_code`, `enabled`, `sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知渠道模板表';

CREATE TABLE IF NOT EXISTS `base_sys_notification_record` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `scene_code` varchar(64) NOT NULL COMMENT '场景编码',
    `channel` varchar(32) NOT NULL COMMENT '发送渠道',
    `target` varchar(255) NOT NULL COMMENT '发送目标',
    `template_id` varchar(32) DEFAULT NULL COMMENT '模板ID',
    `template_title` varchar(255) DEFAULT NULL COMMENT '标题快照',
    `template_content` text COMMENT '内容快照',
    `args_json` text COMMENT '参数JSON',
    `status` varchar(32) NOT NULL COMMENT '发送状态',
    `message_id` varchar(128) DEFAULT NULL COMMENT '消息ID',
    `failure_reason` text COMMENT '失败原因',
    `retry_count` int NOT NULL DEFAULT 0 COMMENT '重试次数',
    `next_retry_time` datetime DEFAULT NULL COMMENT '下次重试时间',
    `sent_time` datetime DEFAULT NULL COMMENT '发送时间',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    KEY `idx_scene_channel_status` (`scene_code`, `channel`, `status`),
    KEY `idx_created_time` (`created_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知发送记录表';

DROP TABLE IF EXISTS base_sys_dict_item;
DROP TABLE IF EXISTS base_sys_dict_type;
CREATE TABLE IF NOT EXISTS `base_sys_dict_type` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `name` varchar(128) NOT NULL COMMENT '字典名称',
    `dict_code` varchar(64) NOT NULL COMMENT '字典编码',
    `source_application` varchar(128) DEFAULT NULL COMMENT '字典定义所属应用，空值表示管理员维护',
    `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态(1:启用;0:禁用)',
    `remark` varchar(255) DEFAULT NULL COMMENT '备注',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_dict_code` (`dict_code`),
    KEY `idx_dict_source_application` (`source_application`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='字典类型表';

CREATE TABLE IF NOT EXISTS `base_sys_dict_item` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `dict_code` varchar(64) NOT NULL COMMENT '字典编码',
    `label` varchar(128) NOT NULL COMMENT '字典项标签',
    `value` varchar(128) NOT NULL COMMENT '字典项值',
    `status` tinyint NOT NULL DEFAULT 1 COMMENT '状态(1:启用;0:禁用)',
    `sort` int NOT NULL DEFAULT 1 COMMENT '排序',
    `tag_type` varchar(16) NOT NULL DEFAULT 'N' COMMENT '标签类型(N/P/S/W/I/D)',
    `created_by` varchar(100) NOT NULL COMMENT '创建人',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_by` varchar(100) NOT NULL COMMENT '更新人',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_dict_value` (`dict_code`, `value`),
    KEY `idx_dict_status_sort` (`dict_code`, `status`, `sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='字典项表';

CREATE TABLE IF NOT EXISTS `base_sys_error_catalog` (
    `id` varchar(32) NOT NULL COMMENT '主键ID',
    `code` varchar(64) NOT NULL COMMENT '全局错误码',
    `default_message` varchar(500) NOT NULL COMMENT '默认文案',
    `source_application` varchar(128) NOT NULL COMMENT '声明应用',
    `owner` varchar(128) NOT NULL DEFAULT '' COMMENT '错误码定义归属',
    `scope` varchar(32) NOT NULL DEFAULT 'APPLICATION' COMMENT 'COMMON或APPLICATION',
    `module` varchar(128) NOT NULL COMMENT '所属模块',
    `source_version` varchar(64) DEFAULT NULL COMMENT '声明版本',
    `http_status` int DEFAULT NULL COMMENT 'HTTP状态码',
    `public_visible` tinyint(1) NOT NULL DEFAULT 1 COMMENT '是否对外展示',
    `deprecated` tinyint(1) NOT NULL DEFAULT 0 COMMENT '是否已废弃',
    `description` varchar(1000) DEFAULT NULL COMMENT '说明',
    `created_by` varchar(100) NOT NULL DEFAULT 'system',
    `created_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_by` varchar(100) NOT NULL DEFAULT 'system',
    `updated_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_error_catalog_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='全局错误码目录';

INSERT INTO `base_sys_captcha_scene` (`id`, `scene_code`, `scene_name`, `captcha_type`, `template_code`, `notification_template_id`, `description`, `captcha_length`, `captcha_expire_time`, `captcha_attempts`, `min_interval`, `max_limit_count`, `enabled`, `created_by`, `updated_by`)
VALUES
('LOGIN_IMAGE', 'LOGIN_IMAGE', '登录时图形验证码', 'IMAGE', NULL, NULL, '登录时图形验证码', 4, 300, 1, 60, 100, 1, 'system', 'system'),
('REGISTER_IMAGE', 'REGISTER_IMAGE', '注册时图形验证码', 'IMAGE', NULL, NULL, '注册时图形验证码', 4, 60, 3, 60, 50, 1, 'system', 'system'),
('LOGIN_SMS', 'LOGIN_SMS', '登录时短信验证码', 'SMS', 'CAPTCHA', 'NOTIFY_TPL_LOGIN_SMS', '登录时短信验证码', 6, 60, 2, 60, 100, 1, 'system', 'system'),
('LOGIN_EMAIL', 'LOGIN_EMAIL', '登录时邮箱验证码', 'EMAIL', 'CAPTCHA', 'NOTIFY_TPL_LOGIN_EMAIL', '登录时邮箱验证码', 6, 300, 3, 60, 100, 1, 'system', 'system');

INSERT INTO `base_sys_notification_scene` (`id`, `scene_code`, `scene_name`, `description`, `enabled`, `created_by`, `updated_by`)
VALUES
('NOTIFY_SCENE_LOGIN_CAPTCHA', 'LOGIN_CAPTCHA', '登录验证码', '登录时发送验证码通知', 1, 'system', 'system'),
('NOTIFY_SCENE_ORDER_CREATED', 'ORDER_CREATED', '订单创建', '订单创建后发送通知', 1, 'system', 'system');

INSERT INTO `base_sys_notification_template` (`id`, `scene_code`, `channel`, `template_name`, `title`, `content`, `param_schema`, `sort`, `enabled`, `created_by`, `updated_by`)
VALUES
('NOTIFY_TPL_LOGIN_SMS', 'LOGIN_CAPTCHA', 'SMS', '登录验证码短信', NULL, '【通知】您的登录验证码为：{code}，请在{minutes}分钟内使用。如非本人操作，请忽略本信息。', 'code:验证码; minutes:有效分钟数', 1, 1, 'system', 'system'),
('NOTIFY_TPL_LOGIN_EMAIL', 'LOGIN_CAPTCHA', 'EMAIL', '登录验证码邮件', '登录验证码', '您的登录验证码为：{code}，请在{minutes}分钟内使用。', 'code:验证码; minutes:有效分钟数', 2, 1, 'system', 'system'),
('NOTIFY_TPL_ORDER_SMS', 'ORDER_CREATED', 'SMS', '订单创建短信', NULL, '【通知】您的订单{orderNo}已提交成功。', 'orderNo:订单号', 1, 1, 'system', 'system'),
('NOTIFY_TPL_ORDER_EMAIL', 'ORDER_CREATED', 'EMAIL', '订单创建邮件', '订单提交成功', '您的订单{orderNo}已提交成功，谢谢。', 'orderNo:订单号', 2, 1, 'system', 'system');

INSERT INTO `base_sys_dict_type` (`id`, `name`, `dict_code`, `status`, `remark`, `created_by`, `updated_by`)
VALUES
('DICT_GENDER', '性别', 'gender', 1, '用户性别', 'system', 'system'),
('DICT_NOTICE_LEVEL', '通知级别', 'notice_level', 1, '通知公告级别', 'system', 'system'),
('DICT_NOTICE_TYPE', '通知类型', 'notice_type', 1, '通知公告类型', 'system', 'system');

INSERT INTO `base_sys_dict_item` (`id`, `dict_code`, `label`, `value`, `status`, `sort`, `tag_type`, `created_by`, `updated_by`)
VALUES
('DICT_GENDER_M', 'gender', '男', 'M', 1, 1, 'P', 'system', 'system'),
('DICT_GENDER_F', 'gender', '女', 'F', 1, 2, 'D', 'system', 'system'),
('DICT_GENDER_UNKNOWN', 'gender', '保密', 'UNKNOWN', 1, 3, 'I', 'system', 'system'),
('DICT_NOTICE_LEVEL_L', 'notice_level', '低', 'L', 1, 1, 'I', 'system', 'system'),
('DICT_NOTICE_LEVEL_M', 'notice_level', '中', 'M', 1, 2, 'W', 'system', 'system'),
('DICT_NOTICE_LEVEL_H', 'notice_level', '高', 'H', 1, 3, 'D', 'system', 'system'),
('DICT_NOTICE_TYPE_UPGRADE', 'notice_type', '系统升级', 'SYSTEM_UPGRADE', 1, 1, 'S', 'system', 'system'),
('DICT_NOTICE_TYPE_MAINTENANCE', 'notice_type', '系统维护', 'SYSTEM_MAINTENANCE', 1, 2, 'P', 'system', 'system'),
('DICT_NOTICE_TYPE_SECURITY', 'notice_type', '安全警告', 'SECURITY_WARNING', 1, 3, 'D', 'system', 'system'),
('DICT_NOTICE_TYPE_HOLIDAY', 'notice_type', '假期通知', 'HOLIDAY_NOTICE', 1, 4, 'S', 'system', 'system'),
('DICT_NOTICE_TYPE_NEWS', 'notice_type', '公司新闻', 'COMPANY_NEWS', 1, 5, 'P', 'system', 'system'),
('DICT_NOTICE_TYPE_OTHER', 'notice_type', '其他', 'OTHER', 1, 99, 'I', 'system', 'system');
