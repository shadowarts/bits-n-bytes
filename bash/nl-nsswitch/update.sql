DELIMITER //
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

