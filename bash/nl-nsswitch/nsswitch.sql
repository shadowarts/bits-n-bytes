DROP DATABASE IF EXISTS `nsswitch`;
CREATE DATABASE `nsswitch`;
USE `nsswitch`;

DROP TABLE IF EXISTS `group`;
CREATE TABLE `group` (
		gid INT(11) NOT NULL,
		name VARCHAR(32) NOT NULL,
		INDEX(name),
		PRIMARY KEY(gid)
		) ENGINE=INNODB;

DROP TABLE IF EXISTS `passwd`;
CREATE TABLE `passwd` (
		uid INT(11) NOT NULL,
		name VARCHAR(32) NOT NULL,
		gid INT(11) NOT NULL,
		created TIMESTAMP DEFAULT NOW(),
		INDEX(name),
		INDEX(gid),
		PRIMARY KEY(uid),
		FOREIGN KEY gid_key (gid) REFERENCES `group` (gid) ON UPDATE CASCADE ON DELETE RESTRICT
		) ENGINE=INNODB;

DROP TABLE IF EXISTS `group_members`;
CREATE TABLE `group_members` (
		uid INT(11) NOT NULL,
		gid INT(11) NOT NULL,
		INDEX(uid),
		INDEX(gid),
		FOREIGN KEY uid_key (uid) REFERENCES `passwd` (uid) ON UPDATE CASCADE ON DELETE CASCADE,
		FOREIGN KEY gid_key (gid) REFERENCES `group` (gid) ON UPDATE CASCADE ON DELETE CASCADE
		) ENGINE=INNODB;

DROP TABLE IF EXISTS `shadow`;
CREATE TABLE `shadow` (
		uid INT(11) NOT NULL,
		password VARCHAR(255) DEFAULT NULL,
		points INT(11) NOT NULL DEFAULT 0,
        PRIMARY KEY(uid),
		FOREIGN KEY uid_key (uid) REFERENCES `passwd` (uid) ON UPDATE CASCADE ON DELETE CASCADE
		) ENGINE=INNODB;

DROP TABLE IF EXISTS `gshadow`;
CREATE TABLE `gshadow` (
		gid INT(11) NOT NULL,
		password VARCHAR(255) DEFAULT NULL,
        PRIMARY KEY(gid),
        FOREIGN KEY gid_key (gid) REFERENCES `group` (`gid`) ON DELETE CASCADE ON UPDATE CASCADE
		) ENGINE=INNODB;

DROP TABLE IF EXISTS `auth_log`;
CREATE TABLE `auth_log` (
		id INT NOT NULL AUTO_INCREMENT,
		time TIMESTAMP DEFAULT NOW(),
		user VARCHAR(32) NOT NULL,
		pid INT(11) NOT NULL,
		ost VARCHAR(255) NOT NULL,
		message TEXT NOT NULL,
		PRIMARY KEY(id)
		) ENGINE=MYISAM;

DROP TABLE IF EXISTS `user_meta`;
CREATE TABLE `user_meta` (
		`uid` INT(11) NOT NULL,
		`key` VARCHAR(32) NOT NULL,
		`value` VARCHAR(255) NOT NULL,
		INDEX(`uid`),
		INDEX(`key`),
		FOREIGN KEY uid_key (uid) REFERENCES `passwd` (uid) ON UPDATE CASCADE ON DELETE CASCADE,
        UNIQUE (`uid`, `key`),
		) ENGINE=INNODB;

DROP TABLE IF EXISTS `user_meta_shadow`;
CREATE TABLE `user_meta_shadow` (
		`uid` INT(11) NOT NULL,
		`key` VARCHAR(32) NOT NULL,
		`value` VARCHAR(255) NOT NULL,
		INDEX(`uid`),
		INDEX(`key`),
		FOREIGN KEY uid_key (uid) REFERENCES `passwd` (uid) ON UPDATE CASCADE ON DELETE CASCADE,
        UNIQUE (`uid`, `key`),
		) ENGINE=INNODB;

DROP TABLE IF EXISTS `user_notes`;
CREATE TABLE `user_notes` (
		id INT(11) NOT NULL AUTO_INCREMENT,
		created TIMESTAMP DEFAULT NOW(),
		uid INT(11) NOT NULL,
		authorid INT(11) NOT NULL,
		amount INT(11) NOT NULL DEFAULT 0,
		description TEXT NOT NULL,
		INDEX(uid),
		INDEX(authorid),
		FOREIGN KEY uid_key (uid) REFERENCES `passwd` (uid) ON UPDATE CASCADE ON DELETE CASCADE,
		FOREIGN KEY author_key (authorid) REFERENCES `passwd` (uid) ON UPDATE CASCADE ON DELETE RESTRICT,
		PRIMARY KEY(id)
		) ENGINE=INNODB;


DELIMITER //
DROP PROCEDURE IF EXISTS nss_create_user //
CREATE PROCEDURE nss_create_user (
		username VARCHAR(32),
		password VARCHAR(255),
		groupname VARCHAR(255),
		firstname VARCHAR(255),
		lastname VARCHAR(255),
		email VARCHAR(255),
		home VARCHAR(255),
		shell VARCHAR(255),
        system INT)
BEGIN
	INSERT INTO `nsswitch`.`passwd` (`uid`, `name`, `gid`) SELECT nss_get_next_uid(system), username, `group`.`gid` FROM `group` WHERE `group`.`name` = groupname;
	CALL nss_set_user_password(username, password);
	CALL nss_set_user_meta(username, "firstname", firstname, 1);
	CALL nss_set_user_meta(username, "lastname", lastname, 1);
	CALL nss_set_user_meta(username, "email", email, 1);
	CALL nss_set_user_meta(username, "home", home, 0);
	CALL nss_set_user_meta(username, "shell", shell, 0);
    CALL nss_add_group_user(username, groupname);
	CALL nss_get_user(username);
END //

DROP PROCEDURE IF EXISTS nss_remove_user //
CREATE PROCEDURE nss_remove_user (
		name VARCHAR(32))
BEGIN
	DELETE FROM `passwd` WHERE `passwd`.`name` = name;
END //

DROP PROCEDURE IF EXISTS nss_get_user // 
CREATE PROCEDURE nss_get_user (
		name VARCHAR(32))
BEGIN
	SELECT * FROM `passwd` WHERE `passwd`.`name` LIKE name;
END //

DROP PROCEDURE IF EXISTS nss_authenticate_user //
CREATE PROCEDURE nss_authenticate_user (
		name VARCHAR(32),
		password VARCHAR(255))
BEGIN
	SELECT * FROM `passwd` INNER JOIN `shadow` ON `passwd`.`uid` = `shadow`.`uid` WHERE `passwd`.`name` = name AND `shadow`.`password` = PASSWORD(password);
END //

DROP PROCEDURE IF EXISTS nss_set_user_password //
CREATE PROCEDURE nss_set_user_password (
		name VARCHAR(32),
		password VARCHAR(255))
BEGIN	
	DELETE FROM `shadow` USING `shadow`, `passwd` WHERE `shadow`.`uid` = `passwd`.`uid` AND `passwd`.`name` = name;

	IF password IS NULL THEN
		INSERT INTO `shadow` (`uid`, `password`) SELECT `uid`, NULL FROM `passwd` WHERE `passwd`.`name` = name;
	ELSE
		INSERT INTO `shadow` (`uid`, `password`) SELECT `uid`, PASSWORD(password) FROM `passwd` WHERE `passwd`.`name` = name;
	END IF;
END //

DROP PROCEDURE IF EXISTS nss_set_user_default_group;
CREATE PROCEDURE nss_set_user_default_group (
		username VARCHAR(32),
		groupname VARCHAR(32))
BEGIN
	UPDATE `passwd`,`group` SET `passwd`.`gid` = `group`.`gid` WHERE `passwd`.`username` = username AND `group`.`name`=groupname;
END //

DROP PROCEDURE IF EXISTS nss_create_group //
CREATE PROCEDURE nss_create_group (
		name VARCHAR(32),
		password VARCHAR(255),
        system INT)
BEGIN
    INSERT INTO `group` (`gid`, `name`) SELECT nss_get_next_gid(system), name;
	CALL nss_set_group_password(name, password);
END //

DROP PROCEDURE IF EXISTS nss_remove_group //
CREATE PROCEDURE nss_remove_group (
		name VARCHAR(32))
BEGIN
	DELETE FROM `group` WHERE `group`.`name` = name;
END //

DROP PROCEDURE IF EXISTS nss_get_group //
CREATE PROCEDURE nss_get_group (
		name VARCHAR(32))
BEGIN
	SELECT * FROM `group` WHERE `group`.`name` LIKE name;
END //

DROP PROCEDURE IF EXISTS nss_authenticate_group //
CREATE PROCEDURE nss_authenticate_group (
		groupname VARCHAR(32),
		username VARCHAR(32),
		password VARCHAR(32))
BEGIN
	SELECT `group`.`name` FROM `group` 
		INNER JOIN `gshadow` ON `gshadow`.`gid`=`group`.`gid`
		INNER JOIN `group_members` ON `group`.`gid` = `group_members`.`gid`
		INNER JOIN `passwd` ON `group_members`.`uid` = `passwd`.`uid`
	WHERE
		`group`.`name` = groupname AND
		(`gshadow`.`passwd` = PASSWORD(password) OR `passwd`.`username`=username);
END //

DROP PROCEDURE IF EXISTS nss_set_group_password //
CREATE PROCEDURE nss_set_group_password (
		name VARCHAR(32),
		password VARCHAR(255))
BEGIN
	DELETE FROM `gshadow` USING `gshadow`, `group` WHERE `gshadow`.`gid` = `group`.`gid` AND `group`.`name` = name;

	IF password IS NULL THEN
		INSERT INTO `gshadow` (`gid`, `password`) SELECT `gid`, NULL FROM `group` WHERE `group`.`name` = name;
	ELSE
		INSERT INTO `gshadow` (`gid`, `password`) SELECT `gid`, PASSWORD(password) FROM `group` WHERE `group`.`name` = name;
	END IF;
END //

DROP PROCEDURE IF EXISTS nss_add_group_user  //
DROP PROCEDURE IF EXISTS nsS_add_group_user  //
CREATE PROCEDURE nss_add_group_user (
		username VARCHAR(32),
		groupname VARCHAR(32))
BEGIN
	INSERT INTO `group_members` (`uid`, `gid`) SELECT `passwd`.`uid`, `group`.`gid` FROM `passwd`, `group` WHERE `passwd`.`name` = username AND `group`.`name` = groupname;
END //

DROP PROCEDURE IF EXISTS nss_remove_group_user //
CREATE PROCEDURE nss_remove_group_user (
		username VARCHAR(32),
		groupname VARCHAR(32))
BEGIN
	DELETE FROM `group_members` USING `group_members`, `group`, `passwd` WHERE `group_members`.`uid` = `passwd`.`uid` AND `passwd`.`name` = username AND `group_members`.`gid` = `group`.`gid` AND `group`.`name` = groupname;	
END //

DROP PROCEDURE IF EXISTS nss_set_user_meta //
CREATE PROCEDURE nss_set_user_meta (
		name VARCHAR(32),
		meta VARCHAR(32),
		value VARCHAR(255),
		private INT)
BEGIN
	IF private = 0 THEN
		REPLACE INTO `user_meta` (`uid`, `key`, `value`) SELECT `passwd`.`uid`, meta, value FROM `passwd` WHERE `passwd`.`name` = name;
	ELSE
		REPLACE INTO `user_meta_shadow` (`uid`, `key`, `value`) SELECT `passwd`.`uid`, meta, value FROM `passwd` WHERE `passwd`.`name` = name;
	END IF;
END //

DROP PROCEDURE IF EXISTS nss_get_user_meta //
CREATE PROCEDURE nss_get_user_meta (
		name VARCHAR(32),
		meta VARCHAR(32),
		private INT)
BEGIN
	IF private = 0 THEN
		SELECT `user_meta`.`key` AS `meta`, `user_meta`.`value` AS `value` FROM `user_meta`
			INNER JOIN `passwd` ON `user_meta`.`uid` = `passwd`.`uid`
	   	WHERE `passwd`.`name` = name AND `user_meta`.`key` LIKE meta;
	ELSE
		SELECT `user_meta_shadow`.`key` AS `meta`, `user_meta_shadow`.`value` AS `value` FROM `user_meta_shadow`
			INNER JOIN `passwd` ON `user_meta_shadow`.`uid` = `passwd`.`uid`
    	WHERE `passwd`.`name` = name AND `user_meta_shadow`.`key` LIKE meta;
	END IF;
END //

DROP PROCEDURE IF EXISTS nss_add_user_note //
CREATE PROCEDURE nss_add_user_note (
		name VARCHAR(32),
		author VARCHAR(32),
		message TEXT,
		points INT(11))
BEGIN
	INSERT INTO `user_notes` (`created`, `uid`, `authorid`, `description`, `amount`) SELECT NOW(), `passwd`.`uid`, 1000, message, points FROM `passwd` WHERE `passwd`.`name` = name;
	UPDATE `user_notes`, `passwd` SET `user_notes`.`authorid`=`passwd`.`uid` WHERE `passwd`.`name` = author AND `user_notes`.`id` = LAST_INSERT_ID();
	/*CALL nss_update_user_points(name);*/
END //

DROP PROCEDURE IF EXISTS nss_update_user_points //
CREATE PROCEDURE nss_update_user_points (
		name VARCHAR(32))
BEGIN
    DECLARE points INT DEFAULT 0;
    SELECT SUM(`amount`) INTO points FROM `user_notes` WHERE `user_notes`.`uid` = nss_get_uid_from_name(name);
    UPDATE `shadow` SET `shadow`.`points` = points WHERE `shadow`.`uid` = nss_get_uid_from_name(name);
END //

DROP FUNCTION IF EXISTS nss_get_next_uid //
CREATE FUNCTION nss_get_next_uid (
    system INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE cur_uid INT DEFAULT 0;

    IF system = 1 THEN
        SELECT MAX(`uid`) INTO cur_uid FROM `passwd` WHERE `passwd`.`uid` < 1000;
        
        IF cur_uid IS NULL THEN
            SET cur_uid = 99;
        END IF;
    ELSE
        SELECT MAX(`uid`) INTO cur_uid FROM `passwd` WHERE `passwd`.`uid` > 999;

        IF cur_uid IS NULL THEN
            SET cur_uid = 999;
        END IF;
    END IF;

    RETURN cur_uid + 1;
END //

DROP FUNCTION IF EXISTS nss_get_next_gid //
CREATE FUNCTION nss_get_next_gid (
    system INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE cur_gid INT DEFAULT 0;

    IF system = 1 THEN
        SELECT MAX(`gid`) INTO cur_gid FROM `group` WHERE `group`.`gid` < 1000;

        IF cur_uid IS NULL THEN
            SET cur_gid = 99;
        END IF;
    ELSE
        SELECT MAX(`gid`) INTO cur_gid FROM `group` WHERE `group`.`gid` > 999;

        IF cur_gid IS NULL THEN
            SET cur_gid = 999;
        END IF;
    END IF;

    RETURN cur_gid + 1;
END //

DROP FUNCTION IF EXISTS nss_get_uid_from_name //
CREATE FUNCTION nss_get_uid_from_name (
    name VARCHAR(32))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE user_id INT DEFAULT 0;
    SELECT `uid` INTO user_id FROM `passwd` WHERE `passwd`.`name` = name;
    RETURN user_id;
END //


DROP USER 'nss_passwd'@'localhost';
CREATE USER 'nss_passwd'@'localhost';
GRANT EXECUTE ON `nsswitch`.* TO 'nss_passwd'@'localhost';
GRANT SHOW VIEW ON `nsswitch`.* TO 'nss_passwd'@'localhost';
GRANT SELECT ON `nsswitch`.`passwd` TO 'nss_passwd'@'localhost';
GRANT SELECT ON `nsswitch`.`group` TO 'nss_passwd'@'localhost';
GRANT SELECT ON `nsswitch`.`group_members` TO 'nss_passwd'@'localhost';
GRANT SELECT ON `nsswitch`.`user_meta` TO 'nss_passwd'@'localhost';

DROP USER 'nss_shadow'@'localhost';
CREATE USER 'nss_shadow'@'localhost' IDENTIFIED BY 'password';
GRANT EXECUTE ON `nsswitch`.* TO 'nss_shadow'@'localhost';
GRANT SHOW VIEW ON `nsswitch`.* TO 'nss_passwd'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`passwd` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`group` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`group_members` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`shadow` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`gshadow` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`auth_log` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`user_meta` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON `nsswitch`.`user_meta_shadow` TO 'nss_shadow'@'localhost';
GRANT SELECT, INSERT ON `nsswitch`.`user_notes` TO 'nss_shadow'@'localhost';

