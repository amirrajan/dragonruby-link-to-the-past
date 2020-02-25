require 'app/gtk_patches.rb'
require 'app/tile.rb'
require 'app/green_thumb_item.rb'

class Game
  attr_gtk

  include GreenThumbItem

  def defaults
    state.show_debug_layer    = true if state.tick_count == 0
    assets.bush.w    = 52
    assets.bush.h    = 46
    assets.bush.path = 'sprites/bush.png'

    player.tile_size              = 64
    player.speed                  = 3
    player.speed_while_charging   = 2
    player.charge_frames          = 90
    player.slash_frames           = 20
    player.spin_frames            = 40
    player.x                    ||= 50
    player.y                    ||= 600
    player.dir_x                ||=  1
    player.dir_y                ||= -1
    player.is_moving            ||= false
    player.item.green_thumb     ||= green_thumb_item
    state.watch_list            ||= {}
    state.bushes                ||= []
  end

  def player_speed
    return player.speed_while_charging if player.slash_charge_at
    return player.speed
  end

  def sprite_horizontal_run
    tile_index = 0.frame_index(6, 3, true)
    tile_index = 0 if !player.is_moving

    {
      x: player.x,
      y: player.y,
      w: player.tile_size,
      h: player.tile_size,
      path: 'sprites/horizontal-run.png',
      tile_x: 0 + (tile_index * player.tile_size),
      tile_y: 0,
      tile_w: player.tile_size,
      tile_h: player.tile_size,
      flip_horizontally: player.dir_x > 0,
    }
  end

  def sprite_horizontal_stand
    {
      x: player.x,
      y: player.y,
      w: player.tile_size,
      h: player.tile_size,
      path: 'sprites/horizontal-stand.png',
      flip_horizontally: player.dir_x > 0,
    }
  end

  def sprite_slash_charging
    {
      x: player.x - 15,
      y: player.y - 15,
      w: player.tile_size + 30,
      h: player.tile_size + 30,
      path: 'sprites/slash-charging.png',
      flip_horizontally: player.dir_x > 0,
    }
  end

  def sprite_horizontal_slash
    tile_index   = player.slash_at.frame_index(5, player.slash_frames.idiv(5), false) || 0

    {
      x: player.x - 32,
      y: player.y - 20,
      w: 128,
      h: 128,
      path: 'sprites/horizontal-slash.png',
      tile_x: 0 + (tile_index * 128),
      tile_y: 0,
      tile_w: 128,
      tile_h: 128,
      flip_horizontally: player.dir_x > 0
    }
  end

  def sprite_spin frame_index_override = nil
    frame_index   = frame_index_override || player.spin_at.frame_index(8, player.spin_frames.idiv(8), false) || 0

    {
      x: player.x - 15,
      y: player.y - 15,
      w: 64 + 30,
      h: 64 + 30,
      path: "sprites/spin-slash-#{frame_index}.png",
      flip_horizontally: player.dir_x > 0
    }
  end

  def render_player
    if player.spin_at
      outputs.sprites << sprite_spin
    elsif player.slash_charge_at
      outputs.sprites << sprite_slash_charging
    elsif player.slash_at
      outputs.sprites << sprite_horizontal_slash
    elsif player.is_moving
      outputs.sprites << sprite_horizontal_run
    else
      outputs.sprites << sprite_horizontal_stand
    end
  end

  def render_bushes
    outputs.sprites << state.bushes
  end

  def render_debug_layer
    return if !state.show_debug_layer
    outputs.debug << state.watch_list.map.with_index do |(k, v), i|
      [30, 710 - i * 28, "#{k}: #{v || "(nil)"}"].label
    end

    outputs.debug << player.slash_collision_rect.border
    outputs.debug << player.spin_collision_rect.border
    outputs.debug << player.item.green_thumb.aoe.map { |r| r.solid.merge(g: 200, w: 5, h: 5) }
    outputs.debug << player.terrain_collision_body.border
  end

  def slash_initiated?
    # buffalo usb controller has a button and b button swapped lol
    inputs.controller_one.key_down.a || inputs.keyboard.key_down.j
  end

  def slash_charge_attempted?
    inputs.controller_one.key_held.a || inputs.keyboard.key_held.j
  end

  def slash_cancelled?
    inputs.controller_one.key_up.a || inputs.keyboard.key_up.j
  end

  def can_charge_sword?

  end

  def input_move_player
    player.is_moving = false
    return if !slash_complete?
    return unless vector = inputs.directional_vector
    player.is_moving = true
    if !player.slash_charge_at
      player.dir_x = vector.x if !vector.x.zero?
      player.dir_y = vector.y if !vector.y.zero?
    end
    vector.x = 0 if Tile.find_intersection(player_next_terrain_collision_body_x, state.bushes)
    vector.y = 0 if Tile.find_intersection(player_next_terrain_collision_body_y, state.bushes)
    state.watch_list[:player_speed] = player_speed
    player.x += vector.x * player_speed
    player.y += vector.y * player_speed
  end

  def calc_movement
    input_move_player
    player.terrain_collision_body = [
      player.x + 15,
      player.y + 15,
      30,
      30
    ]
  end

  def calc_collision_boxes
    # re-calc the location of the swords collision box
    if player.dir_x.pos?
      player.spin_collision_rect = [player.x - 20 , player.y - 20, 95, 95]

      player.slash_collision_rect = [player.x + player.tile_size + 8,
                                     player.y + player.tile_size.half - 10,
                                     20, 20]
    else
      player.spin_collision_rect = [player.x - 20 , player.y - 20, 95, 95]

      player.slash_collision_rect = [player.x - 32,
                                     player.y + player.tile_size.half - 10,
                                     20, 20]
    end
  end

  def calc_slash
    calc_collision_boxes

    player.slash_at = slash_initiated? if slash_initiated? && slash_complete?

    state.watch_list[:slash_charge_at] = player.slash_charge_at
    state.watch_list[:spin_at] = player.spin_at
    state.watch_list[:slash_at] = player.slash_at
    # recalc sword's slash state

    if player.spin_at && spin_completed?
      player.spin_at = nil
    elsif slash_cancelled?
      if player.slash_charge_at &&
         player.slash_charge_at.elapsed?(player.charge_frames)
        player.spin_at = state.tick_count
      else
        player.spin_at = nil
      end
      player.slash_charge_at = nil
    elsif slash_complete?
      player.slash_at = nil
      if slash_charge_attempted?
        player.slash_charge_at ||= state.tick_count
      else
        player.slash_charge_at = nil
      end
    end

    # determine collision if the sword is at it's point of damaging
    if slash_can_damage?
      if holding_green_thumb?
        add_bush Tile.find_intersection_in_many(player.item.green_thumb.aoe,
                                                player.item.green_thumb.placement_locations)
      else
        state.bushes.delete Tile.find_intersection(player.slash_collision_rect,
                                                   state.bushes)
      end
    elsif spin_can_damage?
      state.bushes.delete Tile.find_intersection(player.spin_collision_rect, state.bushes)
    end
  end

  def slash_complete?
    !player.slash_at || player.slash_at.elapsed?(player.slash_frames)
  end

  def spin_completed?
    !player.spin_at || player.spin_at.elapsed?(player.spin_frames)
  end

  def spin_can_damage?
    return false if spin_completed?
    return false if (player.spin_at + 5) > state.tick_count
    true
  end

  def slash_can_damage?
    # damage occurs half way into the slash animation
    return false if slash_complete?
    return false if (player.slash_at + player.slash_frames.idiv(2)) != state.tick_count
    return true
  end

  def calc
    # generate an enemy if there aren't any on the screen
    calc_movement
    calc_slash
    calc_green_thumb_item
  end

  # source is at http://github.com/amirrajan/dragonruby-link-to-the-past
  def tick
    defaults
    render_bushes
    render_player
    render_green_thumb
    render_debug_layer
    outputs.labels << [30, 30, "Gamepad: D-Pad to move. B button to attack."]
    outputs.labels << [30, 52, "Keyboard: WASD/Arrow keys to move. J to attack."]
    calc
  end

  def player
    state.player
  end

  def assets
    state.assets
  end

  def player_next_terrain_collision_body_x
    v_x, _ = inputs.directional_vector || [0, 0]
    player.terrain_collision_body.rect_shift_right(v_x * player_speed)
  end

  def player_next_terrain_collision_body_y
    _, v_y = inputs.directional_vector || [0, 0]
    player.terrain_collision_body.rect_shift_up(v_y * player_speed)
  end
end

$game = Game.new

def tick args
  $game.args = args
  $game.tick
end

def run_regression
  $gtk.reset
  $gtk.start_replay 'replays/regression.txt'
end

def run_spin
  $gtk.reset
  $gtk.start_replay 'replays/spin-slash.txt'
end

def import_sprite desktop_file_name
  $gtk.system "cp ~/Desktop/#{desktop_file_name} ./sprites/#{desktop_file_name}"
end

def debug_layer
  $gtk.args.state.show_debug_layer = !$gtk.args.state.show_debug_layer
end
