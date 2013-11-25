-- target_seek
-- @short: Request a change playback position for a frameserver. 
-- @inargs: vid, seekpos, *rel*
-- @longdescr: Request that the specified decode frameserver try and seek to a different position.
-- This will flush queues in both ends. If *rel* is set to anything other than 1,
-- the seek will be absolute and expected to be a float in the 0..1 range (where 0 denotes beginning 
-- of clip or possible buffer for streams and 1 the end). If *rel* is set to 1 or skipped,
-- the seek will be relative to the current playback position and seekpos is a positive or negative
-- offset in milliseconds.
-- @note: For libretro/hijack cores that support snapshot capabilities, this will enable
-- state tracking and delta-states for rewinding gameplay.
-- @note: A relative seek of 0 ms will still impose a buffer flush.
-- @group: targetcontrol 
-- @cfunction: arcan_lua_targetseek
