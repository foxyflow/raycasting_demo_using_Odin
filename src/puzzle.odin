package main

import rl "vendor:raylib"
import "core:math"

/*
    --- PUZZLE GEOMETRY CHEAT SHEET ---
    HUD Area: X = 0 to 1120 | Y = 640 to 800 (Total Height: 160px)
    Middle of HUD Y: 720
    Safe Movement Zone:
        Top Boundary: 640
        Bottom Boundary: 800 (minus block height)
        Left Boundary: 0
        Right Boundary: 1120 (minus block width)
*/

/*
    HUD DIMENSIONS EXPLAINED:
    ----------------------------------------------------------
    LEFT EDGE:   0
    RIGHT EDGE:  1120
    TOP EDGE:    640  (Anything less than 640 is the 3D world)
    BOTTOM EDGE: 800  (The very bottom of your screen)
    
    Y-COORDINATE MAP:
    640 -> 700:  The "Ceiling" / Navigation area
    700 -> 740:  The "Middle"  / Where blocks usually slide
    740 -> 800:  The "Bolt"    / The floor where the holes are
    ----------------------------------------------------------
*/
// BOLT MAPPING EXAMPLE:
// If you want a thicker bolt, change the Height (the 4th number):
// bolt_shaft := rl.Rectangle{ 400, 740, 720, 60 } 
//                                     ^--Height. Making this 80 makes it thicker.

// BLOCK PLACEMENT EXAMPLE:
// To put a block at the very start of the HUD on the left:
// { pos = {10, 650}, ... }

Block :: struct 
{
    pos:   rl.Vector2,
    size:  rl.Vector2,
    color: rl.Color,
}

Target :: struct
{
    rect:  rl.Rectangle, // The area a block must enter
    color: rl.Color,     // The color that must match the block
}

// --- GLOBAL PUZZLE STATE ---
active_block_index := 0 // Which block (0, 1, or 2) the player is currently moving

// Starting positions for your blocks. 
// Change {X, Y} to move them elsewhere at the start.
puzzle_blocks := [3]Block {
    { pos = {100, 700}, size = {20, 20}, color = rl.RED   },
    { pos = {200, 700}, size = {20, 20}, color = rl.BLUE  },
    { pos = {300, 700}, size = {20, 20}, color = rl.GREEN },
}

// THE BOLT: This is a solid horizontal bar. 
// Format: { X_Start, Y_Start, Width, Height }
// Currently starts at X:400, Y:740. It is 720px long and 60px thick.
bolt_shaft := rl.Rectangle{ 400, 740, 720, 60 } 

// TARGETS: The "Holes" where the blocks must go.
// To move a hole, change the first two numbers {X, Y}.
// NOTE: Y is set to 750 so it sits 'inside' the bolt_shaft (740).
puzzle_targets := [3]Target {
    { rect = {450, 750, 40, 40}, color = rl.RED   }, 
    { rect = {550, 750, 40, 40}, color = rl.BLUE  }, 
    { rect = {650, 750, 40, 40}, color = rl.GREEN }, 
}

// STATIC WALLS: Obstacles that never move.
// You can add more entries to this array to build a maze!
puzzle_walls := [1]rl.Rectangle {
    { 850, 640, 20, 100 }, // A vertical pillar blocking the path
}

update_puzzle :: proc(dt: f32) 
{
    // Pointer to the block we are currently controlling
    active_b := &puzzle_blocks[active_block_index]
    
    // We save the 'old_pos' so if we hit a wall, we can "undo" the movement
    old_pos  := active_b.pos 

    // RESET LOGIC: Returns all blocks to starting positions
    if rl.IsKeyPressed(.R)
    {
        puzzle_blocks[0].pos = {100, 700}
        puzzle_blocks[1].pos = {200, 700}
        puzzle_blocks[2].pos = {300, 700}
    }

    // SWITCH BLOCK: Use Shift to cycle through Red, Blue, and Green
    if rl.IsKeyPressed(.LEFT_SHIFT) || rl.IsKeyPressed(.RIGHT_SHIFT) do active_block_index = (active_block_index + 1) % 3

    // MOVEMENT MATH
    speed: f32 = 250.0
    if rl.IsKeyDown(.LEFT)  || rl.IsKeyDown(.A) do active_b.pos.x -= speed * dt
    if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) do active_b.pos.x += speed * dt
    if rl.IsKeyDown(.UP)    || rl.IsKeyDown(.W) do active_b.pos.y -= speed * dt
    if rl.IsKeyDown(.DOWN)  || rl.IsKeyDown(.S) do active_b.pos.y += speed * dt

    // Create a temporary rectangle for the active block's new position to check collisions
    current_rect := rl.Rectangle{active_b.pos.x, active_b.pos.y, 20, 20}

    // --- COLLISION LOGIC ---
    hit_wall := false
    in_target_column := false
    
    // Check if the block is currently lined up with a "Hole" in the bolt
    for t in puzzle_targets
    {
        // If our X center is roughly aligned with the target X center
        if active_b.pos.x > t.rect.x && active_b.pos.x <= (t.rect.x + t.rect.width -20) do in_target_column = true
    }

    // If we are NOT in a hole and we touch the bolt, we hit a wall
    if !in_target_column && rl.CheckCollisionRecs(current_rect, bolt_shaft) do hit_wall = true
    
    // Check against all static maze walls
    for wall in puzzle_walls 
    {
        if rl.CheckCollisionRecs(current_rect, wall) do hit_wall = true
    }

    // If we hit a wall, jump back to where we were before moving this frame
    if hit_wall do active_b.pos = old_pos

    // --- PUSHING LOGIC ---
    // We loop through the other blocks to see if we ran into them
    for i in 0..<3 
    {
        if i == active_block_index do continue // Skip checking ourselves
        
        other_b := &puzzle_blocks[i]
        other_rect := rl.Rectangle{other_b.pos.x, other_b.pos.y, 20, 20}

        // If we touched another block...
        if rl.CheckCollisionRecs(current_rect, other_rect) 
        {
            // Calculate how much we moved this frame
            push_dir := active_b.pos - old_pos
            // Move the OTHER block by that same amount (the "Push")
            other_b.pos += push_dir
            
            blocked := false
            new_other_rect := rl.Rectangle{other_b.pos.x, other_b.pos.y, 20, 20}
            
            // Check if the block we are PUSHING hit a bolt/wall
            other_in_column := false
            for t in puzzle_targets
            {
                if other_b.pos.x > t.rect.x - 5 && other_b.pos.x < t.rect.x + 5 do other_in_column = true
            }

            if !other_in_column && rl.CheckCollisionRecs(new_other_rect, bolt_shaft) do blocked = true
            
            // Check if the block we are PUSHING hit the third block
            for j in 0..<3 
            {
                if j == i || j == active_block_index do continue
                third_rect := rl.Rectangle{puzzle_blocks[j].pos.x, puzzle_blocks[j].pos.y, 20, 20}
                if rl.CheckCollisionRecs(new_other_rect, third_rect) do blocked = true
            }

            // If the pushed block hit anything, cancel the movement for BOTH blocks
            if blocked 
            {
                other_b.pos -= push_dir
                active_b.pos = old_pos
            }
        }
    }

    // SCREEN BOUNDARIES: Prevent blocks from leaving the HUD area
    if active_b.pos.y < 640 do active_b.pos.y = 640
    if active_b.pos.y > 780 do active_b.pos.y = 780 // 800 - 20 (block size)
    if active_b.pos.x < 0   do active_b.pos.x = 0
    if active_b.pos.x > 1100 do active_b.pos.x = 1100 // 1120 - 20 (block size)

    // --- WIN CONDITION ---
    all_locked := true
    for i in 0..<3 
    {
        // Distance check: If all 3 blocks are within 8 pixels of their target
        if rl.Vector2Distance(puzzle_blocks[i].pos, {puzzle_targets[i].rect.x, puzzle_targets[i].rect.y}) > 30
        {
            all_locked = false
            break
        }
    }

    // If all blocks are in position, switch game mode back to 3D
    if all_locked do current_game_mode = .PLAYING_3D
}

draw_puzzle :: proc() 
{
    // Draw the dark HUD background
    rl.DrawRectangle(0, 640, 1120, 160, rl.Color{25, 25, 30, 255})
    
    // Draw the main body of the metal bolt
    rl.DrawRectangleRec(bolt_shaft, rl.GRAY)

    // Draw the target "Holes"
    for t in puzzle_targets 
    {
        // The background of the hole (dark)
        rl.DrawRectangleRec(t.rect, rl.Color{15, 15, 20, 255})
        // The colored outline to show which block goes there
        rl.DrawRectangleLinesEx(t.rect, 3, t.color)
        
        // A very faint fill of the color inside the hole
        faint_color := t.color
        faint_color.a = 40 
        rl.DrawRectangleRec(t.rect, faint_color)
    }

    // Draw any static maze walls
    for wall in puzzle_walls do rl.DrawRectangleRec(wall, rl.DARKGRAY)

    // Draw our 3 blocks
    for i in 0..<3 
    {
        b := puzzle_blocks[i]
        
        // We round the float positions to integers to prevent "blurriness" on screen
        ix := i32(math.round(b.pos.x))
        iy := i32(math.round(b.pos.y))
        
        // Draw the block itself
        rl.DrawRectangle(ix, iy, 20, 20, b.color)

        // If this is the active block, draw a white selection box around it
        if i == active_block_index 
        {
            // We draw the box slightly larger (ix - 2) so it surrounds the block
            rl.DrawRectangleLines(ix - 2, iy - 2, 24, 24, rl.WHITE)
        }
    }
}

 

    
    /*
    OLD RENDERING
    for !rl.WindowShouldClose() //update loop //This loop will eventraully be a virtual 3d viewport gameloop proc(), then just call it in main.
    {

        // 'dt' (Delta Time) is the time passed since the last frame.
        // We use this so movement is smooth even if the FPS changes.
        dt := rl.GetFrameTime()

        // Torch flicker logic here rather than draw_rays, for preformence
        time := f32(rl.GetTime()) // Grab the clock value here
        torch_flicker = (math.sin(time * 10.0) * 0.5) + (math.sin(time * 25.0) * 0.3) 
        light_range : f32 = 10.0 + torch_flicker //wall light range
        sprite_light_range : f32 = 7.0  + torch_flicker //in sprite()

        input(dt) // input for controls proc below main proc

        update_doors(dt) // door statemachine proc()

        // --- Inside your for !rl.WindowShouldClose() loop, before RENDERING ---

        // Calculate the TOTAL vertical shift (Bobbing + Pitch)
        base_bob := math.sin(walk_timer_for_headbob) * 4.0
        camera_dip := stop_shake * 2.5 
        // This is the "Master Offset" for the whole frame
        total_v_offset := base_bob + camera_dip + look_pitch

        // --- RENDERING ---
        rl.BeginTextureMode(target) 
        {
            // 1. BASE: The Floor color (acts as safety if everything else fails)
            rl.ClearBackground(rl.Color{130, 20, 20, 255}) // change to black if sky tint off

            // 2. HORIZON: The "Meeting point" of sky and floor
            // We add the total offset here so the floor/sky move when you look or bob
                
                    // 1. DRAW 3D SKYBOX (The red-tinted flashlight effect)
            // Tint: Dark Red {130, 20, 20, 255}
            // 1. Draw the REAL sky (Top)
            //rl.Color{130, 20, 20, 255} // was where ref is
            // real sky
            draw_skybox_3d(&skybox,rl.Color{130, 20, 20, 255}, false)

            // 2. DRAW FLOOR (Keep your existing rectangle logic for the floor)
            horizon := (WORLD_HEIGHT / 2) + i32(total_v_offset)
            // We use ScissorMode to limit drawing to the floor area only
            rl.BeginScissorMode(0, horizon, GAME_WIDTH, GAME_HEIGHT)
            // We pass 'true' to a new reflection toggle in our proc
            //rl.Color{80, 15, 15, 100} was where ref is. Alpha was 100
            reflection_alpha := i32(clamp(20 + torch_flicker * 5, 0, 255))
            draw_skybox_3d(&skybox,rl.Color{20, 35, 20, u8(reflection_alpha)} , true) 
            //rl.DrawRectangle(0, horizon, GAME_WIDTH, GAME_HEIGHT, rl.Color{25, 15, 10, 150})
            rl.EndScissorMode()

            // rl.DrawRectangle(0, horizon, GAME_WIDTH, WORLD_HEIGHT * 2, rl.Color{20, 10, 10, 255}) //makes brown
            // rl.DrawRectangle(0, horizon, GAME_WIDTH, GAME_HEIGHT, rl.Color{130, 20, 20, 40}) //makes brown shimmer
            //sheen to make floor shinny

            // 3. SKY: Draw from the very top down to the moving horizon
            // Start at -WORLD_HEIGHT so it never runs out when looking down
                // rl.DrawRectangle(0, -WORLD_HEIGHT, GAME_WIDTH, horizon + WORLD_HEIGHT, rl.Color{10, 10, 30, 255})

            // 4. FLOOR: Draw from the moving horizon down to the bottom
            // We make it extra tall (WORLD_HEIGHT * 2) so it never runs out when looking up
                //rl.DrawRectangle(0, horizon, GAME_WIDTH, WORLD_HEIGHT * 2, rl.Color{40, 40, 45, 255})
                // 3. Draw your floor rectangle (slightly transparent so the reflection shows through)
            rl.DrawRectangle(0, horizon, GAME_WIDTH, GAME_HEIGHT, rl.Color{20, 20, 25, 60})

            // 5. WALLS: Pass the total_v_offset into your raycaster
            
            draw_rays(light_range, total_v_offset) 
            
            // 6. HUD: Mask the bottom 40px so nothing "leaks" onto your dashboard
            draw_hud_background() 
            
            // 7. SPRITES & HUD TEXT
            draw_sprites(light_range, total_v_offset) // Sprites need the offset too!
            draw_hud_foreground() 
            
        }
        rl.EndTextureMode()

        rl.BeginDrawing()
        {          
            rl.ClearBackground(rl.BLACK) // Clear the actual 4K monitor
            // Source: The whole tiny texture. 
            // Note: We use -GAME_HEIGHT because textures are upside down in memory.
            src := rl.Rectangle{ 0, 0, f32(GAME_WIDTH), -f32(GAME_HEIGHT) }
            // Destination: The whole big window
            dst := rl.Rectangle{ 0, 0, f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT) }
            // Draw the tiny game stretched up to the big window size
            rl.DrawTexturePro(target.texture, src, dst, {0,0}, 0, rl.WHITE)

            if current_game_mode == .PLAYING_2D do draw_puzzle() 
            {
                
            }else{
                rl.BeginTextureMode(target) 
                rl.EndTextureMode()
            }      
        }
        draw_minimap_hifi(1120, 640) 
       
        rl.EndDrawing()
    }
    //update_2d_platformer(plat_dt, player_vel, plat_player_jumped)

    fmt.println("Process Finished. Checking for leaks...") // delete later
    
}
*/

/*
                    // --- 6. OPTIONAL: THE OLD "SHEEN" --- add before                 }
                rl.EndScissorMode()
                    // If it's still too bright, uncomment the line below to add your old dark overlay
                    rl.DrawRectangle(0, horizon, GAME_WIDTH, GAME_HEIGHT, rl.Color{20, 20, 25, 40})
*/