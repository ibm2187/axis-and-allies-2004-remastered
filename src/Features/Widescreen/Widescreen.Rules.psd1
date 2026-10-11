# Widescreen layout rules: (file inside Data.rwd, line of the block header or of its L
# assignment, kind). Kinds:
#   right    shift by E (things that belong at the right edge)
#   center   shift by E/2 (dialogs and centered panels)
#   stretch  widen by E, keeping the left edge
#   scale    scale a child's position and width with a parent Parent units wide that was stretched
#   width    set L = Left and the width to Width
#   box      turn a full-screen root into a centered 1024-wide box
#   tooltip  shift an anchored_tooltip_x by E (Anchor right) or E/2 (Anchor center)
# E is the extra virtual width: 768 * aspect - 1024.
@{
  Rules = @(
    # main menus: the button column belongs at the right edge
    @{ File = 'UI/Menus/main.tgi'; Line = 14; Kind = 'right' }
    @{ File = 'UI/Menus/singleplayer_menu.tgi'; Line = 4; Kind = 'right' }
    @{ File = 'UI/Menus/multiplayer.tgi'; Line = 4; Kind = 'right' }
    @{ File = 'UI/Menus/menu_background.tgi'; Line = 46; Kind = 'right' }
    # full-screen menu screens: centered 4:3 box
    @{ File = 'UI/Loading/loading_screen.tgi'; Line = 15; Kind = 'box' }
    @{ File = 'UI/Menus/choose_campaign.tgi'; Line = 18; Kind = 'box' }
    @{ File = 'UI/Menus/credits.tgi'; Line = 15; Kind = 'box' }
    @{ File = 'UI/Menus/debriefing.tgi'; Line = 22; Kind = 'box' }
    @{ File = 'UI/Menus/lobby.tgi'; Line = 95; Kind = 'box' }
    @{ File = 'UI/Menus/scoring.tgi'; Line = 8; Kind = 'box' }
    @{ File = 'UI/Menus/staging.tgi'; Line = 115; Kind = 'box' }
    @{ File = 'UI/Shared/options_dialog.tgi'; Line = 179; Kind = 'box' }
    # (UI/Shared/video.tgi is left alone: boxing FullscreenVideoWidget stalls the intro videos)
    # in-game HUD
    @{ File = 'UI/Game/action_buttons.tgi'; Line = 4; Kind = 'right' }
    @{ File = 'UI/Game/control_panel.tgi'; Line = 69; Kind = 'right' }  # objectives button
    @{ File = 'UI/Game/control_panel.tgi'; Line = 99; Kind = 'right' }  # technology button
    @{ File = 'UI/Game/control_panel.tgi'; Line = 129; Kind = 'right' }  # politics button
    @{ File = 'UI/Game/control_panel.tgi'; Line = 159; Kind = 'right' }  # message log button
    @{ File = 'UI/Game/time_message.tgi'; Line = 3; Kind = 'right' }
    @{ File = 'UI/Game/time_message.tgi'; Line = 18; Kind = 'right' }
    @{ File = 'UI/Game/politics_display.tgi'; Line = 20; Kind = 'right' }
    @{ File = 'UI/Game/object_display.tgi'; Line = 2; Kind = 'stretch' }  # keep left-aligned in the panel, widen
    # economy bars sit over the info display: widen them the same way, and scale their fields
    # with the stretched bar art so values stay between the painted separators
    @{ File = 'UI/Game/economy_bar.tgi'; Line = 1; Kind = 'stretch' }
    @{ File = 'UI/Game/economy_bar.tgi'; Line = 15; Kind = 'stretch' }
    @{ File = 'UI/Game/template_game.tgi'; Line = 430; Kind = 'scale'; Parent = 459 }  # money
    @{ File = 'UI/Game/template_game.tgi'; Line = 440; Kind = 'scale'; Parent = 459 }  # ammo
    @{ File = 'UI/Game/template_game.tgi'; Line = 450; Kind = 'scale'; Parent = 459 }  # oil
    @{ File = 'UI/Game/template_game.tgi'; Line = 461; Kind = 'scale'; Parent = 459 }  # building limit
    @{ File = 'UI/Game/template_game.tgi'; Line = 484; Kind = 'scale'; Parent = 459 }  # unit limit
    @{ File = 'UI/Game/template_game.tgi'; Line = 507; Kind = 'scale'; Parent = 459 }  # faction experience
    @{ File = 'UI/Game/favorites_display.tgi'; Line = 2; Kind = 'center' }
    @{ File = 'UI/Game/objectives_display.tgi'; Line = 1; Kind = 'center' }
    @{ File = 'UI/Game/technology_display.tgi'; Line = 1; Kind = 'center' }
    @{ File = 'UI/Game/game_interface.tgi'; Line = 84; Kind = 'center' }  # side message log panel
    @{ File = 'UI/Game/game_interface.tgi'; Line = 460; Kind = 'center' }  # upkeep shortage icon
    @{ File = 'UI/Shared/display_banner.tgi'; Line = 75; Kind = 'center' }
    @{ File = 'UI/Shared/display_banner.tgi'; Line = 87; Kind = 'center' }
    # dialogs
    @{ File = 'UI/Game/chat_panel.tgi'; Line = 1; Kind = 'center' }
    @{ File = 'UI/Game/connection_status_dialog.tgi'; Line = 2; Kind = 'center' }
    @{ File = 'UI/Game/file_dialog.tgi'; Line = 1; Kind = 'center' }
    @{ File = 'UI/Game/game_menu.tgi'; Line = 4; Kind = 'center' }
    @{ File = 'UI/Game/game_menu.tgi'; Line = 175; Kind = 'center' }
    # long labels ("Quit Axis & Allies", "Connection Status") overflow the 182-unit menu button
    # without the old horizontal stretch: widen to 220, centered in the dialog
    @{ File = 'UI/Game/game_menu.tgi'; Line = 20; Kind = 'width'; Left = 82; Width = 220 }  # separator
    @{ File = 'UI/Game/game_menu.tgi'; Line = 60; Kind = 'width'; Left = 82; Width = 220 }  # options
    @{ File = 'UI/Game/game_menu.tgi'; Line = 75; Kind = 'width'; Left = 82; Width = 220 }  # load
    @{ File = 'UI/Game/game_menu.tgi'; Line = 90; Kind = 'width'; Left = 82; Width = 220 }  # save
    @{ File = 'UI/Game/game_menu.tgi'; Line = 105; Kind = 'width'; Left = 82; Width = 220 }  # connection status
    @{ File = 'UI/Game/game_menu.tgi'; Line = 120; Kind = 'width'; Left = 82; Width = 220 }  # abort mission
    @{ File = 'UI/Game/game_menu.tgi'; Line = 152; Kind = 'width'; Left = 82; Width = 220 }  # quit
    @{ File = 'UI/Game/game_menu.tgi'; Line = 167; Kind = 'width'; Left = 82; Width = 220 }  # return to game
    @{ File = 'UI/Game/game_menu.tgi'; Line = 199; Kind = 'width'; Left = 73; Width = 220 }  # resign dialog: resign
    @{ File = 'UI/Game/game_menu.tgi'; Line = 214; Kind = 'width'; Left = 73; Width = 220 }  # leave game
    @{ File = 'UI/Game/game_menu.tgi'; Line = 229; Kind = 'width'; Left = 73; Width = 220 }  # cancel
    @{ File = 'UI/Lobby/player_profile_dialog.tgi'; Line = 638; Kind = 'center' }
    @{ File = 'UI/Menus/create_game_dialog.tgi'; Line = 2; Kind = 'center' }
    @{ File = 'UI/Menus/join_direct_dialog.tgi'; Line = 2; Kind = 'center' }
    @{ File = 'UI/Menus/login.tgi'; Line = 4; Kind = 'center' }
    @{ File = 'UI/Menus/menu_file_dialog.tgi'; Line = 5; Kind = 'center' }
    @{ File = 'UI/Menus/profile_management.tgi'; Line = 4; Kind = 'center' }
    @{ File = 'UI/Menus/server_info_dialog.tgi'; Line = 2; Kind = 'center' }
    @{ File = 'UI/Menus/staging.tgi'; Line = 2; Kind = 'center' }  # map preview dialog
    @{ File = 'UI/Shared/buddy_dialog.tgi'; Line = 2; Kind = 'center' }
    @{ File = 'UI/Shared/buddy_dialog.tgi'; Line = 261; Kind = 'center' }
    @{ File = 'UI/Shared/download_dialog.tgi'; Line = 4; Kind = 'center' }
    @{ File = 'UI/Shared/file_dialog.tgi'; Line = 5; Kind = 'center' }
    @{ File = 'UI/Shared/file_dialog.tgi'; Line = 137; Kind = 'center' }
    @{ File = 'UI/Shared/file_dialog.tgi'; Line = 275; Kind = 'center' }
    @{ File = 'UI/Shared/multiplayer_options_dialog.tgi'; Line = 7; Kind = 'center' }
    @{ File = 'UI/Shared/staging_file_dialog.tgi'; Line = 2; Kind = 'center' }
    @{ File = 'UI/Shared/staging_file_dialog.tgi'; Line = 249; Kind = 'center' }
    @{ File = 'UI/Shared/staging_file_saved_dialog.tgi'; Line = 3; Kind = 'center' }
    @{ File = 'UI/Shared/team_management_dialog.tgi'; Line = 41; Kind = 'center' }
    @{ File = 'UI/Editor/map_properties.tgi'; Line = 4; Kind = 'center' }
    @{ File = 'UI/Editor/new_map_dialog.tgi'; Line = 4; Kind = 'center' }
    @{ File = 'UI/Editor/objectives_dialog.tgi'; Line = 4; Kind = 'center' }
    @{ File = 'UI/Editor/properties_dialog.tgi'; Line = 7; Kind = 'center' }
    # anchored tooltips: x is the tooltip's right edge (left edge when it expands downward), in
    # screen units, so it follows the panel it sits over
    @{ File = 'UI/Game/game_interface.tgi'; Line = 180; Kind = 'tooltip'; Anchor = 'right' }  # over the command panel
    # campaign world map. The control panel art is three buildings with widgets over all of
    # them and nothing that stretches cleanly, so the panel is boxed and the map shows at the
    # sides. Object display and command buttons are its children and move with it; the minimap
    # is a sibling (AA.exe 0x935446 adds it to the interface) and is shifted to match.
    @{ File = 'MetaGame/UI/metagame_cp.tgi'; Line = 7; Kind = 'box' }
    @{ File = 'MetaGame/UI/metagame_minimap.tgi'; Line = 11; Kind = 'center' }
    @{ File = 'MetaGame/UI/metagame_interface.tgi'; Line = 8; Kind = 'tooltip'; Anchor = 'center' }  # right edge of the panel
    @{ File = 'MetaGame/UI/metagame_politics_display.tgi'; Line = 21; Kind = 'right' }
    @{ File = 'MetaGame/UI/metagame_menu.tgi'; Line = 8; Kind = 'center' }
    @{ File = 'MetaGame/UI/metagame_history.tgi'; Line = 8; Kind = 'center' }
    @{ File = 'MetaGame/UI/metagame_help_popup.tgi'; Line = 8; Kind = 'center' }
    @{ File = 'MetaGame/UI/metagame_start_battle.tgi'; Line = 8; Kind = 'center' }
    @{ File = 'MetaGame/UI/metagame_purchasing.tgi'; Line = 8; Kind = 'tooltip'; Anchor = 'center' }
    @{ File = 'MetaGame/UI/metagame_purchasing.tgi'; Line = 14; Kind = 'center' }
    @{ File = 'MetaGame/UI/choose_dynamic_campaign.tgi'; Line = 69; Kind = 'tooltip'; Anchor = 'center' }
    @{ File = 'MetaGame/UI/choose_dynamic_campaign.tgi'; Line = 76; Kind = 'box' }
  )
}
