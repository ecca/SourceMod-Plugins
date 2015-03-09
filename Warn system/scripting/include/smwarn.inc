#if defined _smwarn_included
  #endinput
#endif
#define _smwarn_included

/*********************************************************
 * Issue a warning on a player
 *
 * @param client		The client to issue a warning on
 * @param reason		The reason why you issue a warning on client
 * @noreturn		
 *********************************************************/
native smwarn_warn(client, String:reason[]);

/*********************************************************
 * Remove a warning on a player
 *
 * @param client		The client to remove the warning on
 * @param reason		The reason why you remove the warning
 * @noreturn		
 *********************************************************/
native smwarn_unwarn(client, String:reason[]);

/*********************************************************
 * Reset a players warnings
 *
 * @param client		The client to reset the warnings on
 * @param reason		The reason why you reset the warnings
 * @noreturn		
 *********************************************************/
native smwarn_resetwarn(client, String:reason[]);