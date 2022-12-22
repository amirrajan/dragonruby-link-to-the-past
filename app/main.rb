class Game
  attr_gtk

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
    player.items                ||= state.new_entity(:items)
    player.items.green_thumb    ||= green_thumb_item
    state.watch_list            ||= {}
    state.bushes                ||= []
  end

  def tick
    defaults
    render
    calc
  end

  def render
    render_bushes
    render_player
    render_green_thumb
    render_debug_layer
  end

  def render_debug_layer
    return if !state.show_debug_layer
    outputs.debug << state.watch_list.map.with_index do |(k, v), i|
      { x: 30, y: 710 - i * 28, text: "#{k}: #{v || "(nil)"}" }
    end

    outputs.debug << player.slash_collision_rect.border
    outputs.debug << player.spin_collision_rect.border
    outputs.debug << player.items.green_thumb.aoe.map { |r| r.solid.merge(g: 200, w: 5, h: 5) }
    outputs.debug << player.terrain_collision_body.to_border
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

  def calc_slash
    calc_collision_boxes

    player.slash_at = slash_initiated? if slash_initiated? && slash_complete?

    state.watch_list[:slash_charge_at] = player.slash_charge_at
    state.watch_list[:spin_at] = player.spin_at
    state.watch_list[:slash_at] = player.slash_at
    state.watch_list[:holding_green_thumb] = holding_green_thumb?

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
        add_bush find_intersection_in_many(player.items.green_thumb.aoe,
                                           player.items.green_thumb.placement_locations)
      else
        state.bushes.delete find_intersection(player.slash_collision_rect, state.bushes)
      end
    elsif spin_can_damage?
      state.bushes.delete find_intersection(player.spin_collision_rect, state.bushes)
    end
  end

  def calc_movement
    input_move_player
    player.terrain_collision_body = {
      x: player.x + 15,
      y: player.y + 15,
      w: 30,
      h: 30
    }
  end

  def slash_initiated?
    # buffalo usb controller has a button and b button swapped lol
    inputs.controller_one.key_down.a || inputs.keyboard.key_down.j
  end

  def slash_cancelled?
    inputs.controller_one.key_up.a || inputs.keyboard.key_up.j
  end

  def slash_charge_attempted?
    inputs.controller_one.key_held.a || inputs.keyboard.key_held.j
  end

  def calc_collision_boxes
    # re-calc the location of the swords collision box
    if player.dir_x > 0
      player.spin_collision_rect = { x: player.x - 20, y: player.y - 20, w: 95, h: 95 }

      player.slash_collision_rect = { x: player.x + player.tile_size + 8,
                                      y: player.y + player.tile_size.half - 10,
                                      w: 20, h: 20 }
    else
      player.spin_collision_rect = { x: player.x - 20 , y: player.y - 20, w: 95, h: 95 }

      player.slash_collision_rect = { x: player.x - 32,
                                      y: player.y + player.tile_size.half - 10,
                                      w: 20, h: 20 }
    end
  end

  def render_bushes
    outputs.sprites << state.bushes
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
  def input_move_player
    player.is_moving = false
    return if !slash_complete?
    return unless vector = inputs.directional_vector
    player.is_moving = true
    if !player.slash_charge_at
      player.dir_x = vector.x if !vector.x.zero?
      player.dir_y = vector.y if !vector.y.zero?
    end
    vector.x = 0 if find_intersection(player_next_terrain_collision_body_x, state.bushes)
    vector.y = 0 if find_intersection(player_next_terrain_collision_body_y, state.bushes)
    state.watch_list[:player_speed] = player_speed
    player.x += vector.x * player_speed
    player.y += vector.y * player_speed
  end

  def player
    state.player ||= state.new_entity(:player)
    state.player
  end

  def assets
    state.assets ||= state.new_entity(:assets)
    state.assets
  end

  def player_next_terrain_collision_body_x
    v = inputs.directional_vector || { x: 0, y: 0 }
    player.terrain_collision_body.rect_shift_right(v.x * player_speed)
  end

  def player_next_terrain_collision_body_y
    v = inputs.directional_vector || { x: 0, y: 0 }
    player.terrain_collision_body.rect_shift_up(v.y * player_speed)
  end

  def player_speed
    return player.speed_while_charging if player.slash_charge_at
    return player.speed
  end

  def add_bush point
    return if !point
    return if state.bushes.any? { |b| b[:x] == point.x && b[:y] == point.y }
    state.bushes << { x: point.x,
                      y: point.y,
                      w: assets.bush.w,
                      h: assets.bush.h,
                      path: assets.bush.path }
  end

  def green_thumb_item
    state.new_entity_strict(:bush) do |b|
      b.placement_locations = grid_tiles(assets.bush.w, assets.bush.h)
      b.aoe = []
      b.cast_area = nil
    end
  end

  def holding_green_thumb?
    inputs.controller_one.r1
  end

  def render_green_thumb
    return unless holding_green_thumb?
    outputs.sprites << find_intersections(player.items.green_thumb.cast_area,
                                               player.items.green_thumb.placement_locations).map {|t| t.merge(path: assets.bush.path, a: 80)}

    location = find_intersection_in_many(
      player.items.green_thumb.aoe,
      player.items.green_thumb.placement_locations
    )

    if location
      outputs.sprites  << location.merge(a: 128, path: assets.bush.path)
    end
  end

  def calc_green_thumb_item
    # re-calc the location of the swords collision box
    if player.dir_x > 0
      player.items.green_thumb.aoe = [
        { x: player.x + player.tile_size + 27,
          y: player.y + player.tile_size.half + 10,
          w: 1, h: 1 },
      ]
    else
      player.items.green_thumb.aoe = [
        { x: player.x - 36,
          y: player.y + player.tile_size.half + 10,
          w: 1,
          h: 1 },
      ]
    end

    player.items.green_thumb.cast_area = [player.x - (assets.bush.w),
                                         player.y - assets.bush.h * 1.5,
                                         assets.bush.w * 4, assets.bush.h * 4]

  end

  def grid_tiles w, h
    grid.w
        .idiv(w).+(1)
        .map_with_ys(grid.h.idiv(h).+(1)) do |x, y|
      { x: x * w, y: y * h, w: w, h: h }
    end
  end

  def find_intersection with, tiles
    return nil if !with
    return nil if !tiles
    tiles.find { |t| t.intersect_rect? with }
  end

  def find_intersection_in_many withs, tiles
    return nil if !withs
    return nil if !tiles
    withs.map { |w| find_intersection w, tiles }.first
  end

  def find_intersections with, tiles
    return [] if !with
    return [] if !tiles
    tiles.find_all { |t| t.intersect_rect? with }
  end
end

$game = Game.new
def tick args
  $game.args = args
  $game.tick
end

$gtk.reset
