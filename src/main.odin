package main

import rl "vendor:raylib"
import gl "vendor:raylib/rlgl" //for skybox
import "core:math"
import "core:strings"

//free memory -- top of main, delete before relaese, + the imports below.
import "core:fmt"
import "core:mem"
import "core:os"

Game_Mode::enum
{
    PLAYING_3D,
    PLAYING_2D,
}
current_game_mode:= Game_Mode.PLAYING_3D
//---------2D Globals------------------

//--------------------------------------

//3D
// The "Virtual" resolution (What the game thinks it is)
GAME_WIDTH  :: 320 // SCREEN_WIDTH
GAME_HEIGHT :: 200 //  SCREEN_HEIGHT

// The "Window" resolution (What you actually see)
// Multiplying by 4 makes it 1280x800, which is great for 4K
WINDOW_WIDTH  :: GAME_WIDTH * 4  // 1280 real px
WINDOW_HEIGHT :: GAME_HEIGHT * 4 // 800 real px
WORLD_HEIGHT  :: 160 // 3D viewport excluding HUD 
HUD_HEIGHT    :: 40

MAP_SIZE      :: 64
MAP_COUNT     :: 4096 // 64 * 64 grid flattened or topdown.


// --- Globals (Data used by the whole program) ---
//The Direction vector points straight out of your nose.
// The Plane vector represents your peripheral vision (the width of the screen).
world_map: [MAP_COUNT]int
plane_x : f32 = 0.0 //camera plane. and plane_y. These x and y make a vector. we use this for perppendicular 90degree movement for 3D effect.
plane_y : f32 = 0.66 // This creates the 66-degree FOV (Field of View)

//[2]f32 is shorthand or pos.x and pos.y or struct {x,y: f32} using .x instead of [0]. Raylib uses rl.Vector.
// Player State 
//if play pos at grid x 10.5 and y 7.2, you are in grid 10 and 7 of world_map.
// extra info.: "Stride" formula (y<<6 + x) or index = (7x64)+ 10 = 458. <<6 bitshift is 2 to the power of 6 = 64.
player_pos: [2]f32 // x2floats. [0] is X left right, [1] is Y forward backward [0] + [1] = [2] in Odin.
dir_x:      f32 = 1.0
dir_y:      f32 = 0.0
move_speed: f32 = 5.0
//player
// I need to make a player struct and  maybe proc()
look_pitch: f32 = 0.0 // 0.0 is center, positive is up, negative is down, this is global.


// images 
GameTextures :: struct
{
    soldier : rl.Texture2D, // E
    stonewall : rl.Texture2D, // #
    brownstonewall : rl.Texture2D, // B
    brownstonewallwindow : rl.Texture2D, // W
    door: rl.Texture2D,
    sky:rl.Texture2D,
    stone_pathway_diff:rl.Texture2D,
    stone_pathway_disp:rl.Texture2D,
    stone_pathway_rough:rl.Texture2D,

}
textures: GameTextures

Skybox::struct
{
    skybox_model : rl.Model,
    sky_camera   : rl.Camera3D, // We'll keep a dedicated camera for the sky
    tint: rl.Color,
}
skybox: Skybox

// Global for floor reflection redendering in render_wall_column()
wall_bottoms: [GAME_WIDTH]i32


// Enemy, memory layout each row is an enemy, there are 2 columns x and y.
enemies_dynamic_array: [dynamic][2]f32 //ascii E. array of arrays, list can grow or shrink if more enemy or dies,  

z_buffer: [GAME_WIDTH]f32 //gets vertical lines of 3dviewport world and calulates so enemies don't walk through walls
torch_flicker: f32

walk_timer_for_headbob: f32 = 0.0

player_vel : f32 = 0.0  // Current momentum
acceleration : f32 = 5.0 // How fast you speed up
friction     : f32 = 4.0 // How fast you slide to a stop
strafe_vel : f32
stop_shake : f32 = 0.0 // The current "extra" shake intensity (trying to just shake a little like slowing down from running)

DoorType  :: enum { Regular, Secret }
DoorState :: enum { Closed, Opening, Open, Closing, Moving, Finished }
//----------------door statemachine declare -----------------------------
Door :: struct {
    grid_pos:   [2]i32, //int for grid x and y
    type:       DoorType,
    state:      DoorState,
    offset:     f32,       
    timer:      f32,       
    move_dir:   [2]i32, //int-step on grid such as {1,0} to move East or {0,-1} to move North.
    is_active:  bool,
    tiles_moved: i32,
}

MAX_DOORS      :: 64
door_registry  : [MAX_DOORS]Door
door_count     : int = 0
door_metadata  : [MAP_COUNT]i32 // Lookup table for the raycaster
//-------------------end door state declares -----------------------------

// The "E1M1" ASCII layout
MAP_DATA :: `
################################################################
#######D########################################################
##.###WD####..########........................................##
##....................................E.......................##
##.W.......#..########...........E............................##
##.#.W........S......#........................................##
####S#BWBB##..##D#D###........................................##
##....E..............#........................................##
##.#########..########........................................##
##.#.......#..#......#######..................................##
##.#.......#..#..P...S....S.....#.............................##
##.#.......#..#......############.............................##
##.#########..###D####........................................##
##..............#.#...........................................##
##.##############.####........................................##
##.#.........................................................###
##.#.................#........................................##
##.#.................#........................................##
##.###########..################################################
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#.............................................##
##...........#..#..........................##########.........##
##..................................................#.........##
################################################################
################################################################
`
// Z-Order for main loop
//1 Draw Floor/Ceiling (The bottom layer)
//2 Draw Rays / 3D Walls (The middle layer)
//3 Draw HUD Background (The top layer - covers 3D walls at the bottom)
//4 Draw Minimap & Rays (The "Top-Top" layer - sits on the HUD)

main :: proc()
{
    // --- 1. THE TRACKER (MUST BE FIRST) ---
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    defer 
    {
        if (len(track.allocation_map) > 0) 
        {
            fmt.printf("\n=== %v allocations not freed: ===\n", len(track.allocation_map))
            for _, entry in track.allocation_map 
            {
                fmt.printf("- %v bytes @ %v\n", entry.size, entry.location)
            }
            fmt.println("\nLEAK DETECTED! Press Enter to close...")
            buf: [1]u8
            os.read(os.stdin, buf[:])
        }
        mem.tracking_allocator_destroy(&track)
    }

    // --- 2. INITIALIZATION ---
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Odin Raylib Wolfenstein3D")
    defer rl.CloseWindow()

    rl.DisableCursor() 
    rl.SetTargetFPS(60)

    // Load Textures
    textures.soldier = rl.LoadTexture("E:/clionOdinGame/assets/images/soldier.bmp")
    textures.stonewall = rl.LoadTexture("E:/clionOdinGame/assets/images/stonewall.png")
    textures.door = rl.LoadTexture("E:/clionOdinGame/assets/images/door.png")
    textures.brownstonewall = rl.LoadTexture("E:/clionOdinGame/assets/images/brownstonewall.bmp")
    textures.brownstonewallwindow = rl.LoadTexture("E:/clionOdinGame/assets/images/brownstonewallwindow.bmp")
    textures.sky = rl.LoadTexture("E:/clionOdinGame/assets/images/sky_4k.png")
    textures.stone_pathway_diff = rl.LoadTexture("E:/clionOdinGame/assets/images/stone_pathway_diff_1k.png")
    textures.stone_pathway_disp = rl.LoadTexture("E:/clionOdinGame/assets/images/stone_pathway_disp_1k.png")
    textures.stone_pathway_rough = rl.LoadTexture("E:/clionOdinGame/assets/images/stone_pathway_rough_1k.png")

    // IMPORTANT: Set Wrap to REPEAT so the floor can scroll/tile
    // rl.SetTextureWrap(textures.stone_pathway_diff, .REPEAT)
    // rl.SetTextureWrap(textures.stone_pathway_disp, .REPEAT)
    // rl.SetTextureWrap(textures.stone_pathway_rough, .REPEAT)

    // Retro Pixel Filtering
    rl.SetTextureFilter(textures.stonewall, .POINT)
    rl.SetTextureFilter(textures.door, .POINT)
    rl.SetTextureFilter(textures.sky, .POINT)
    rl.SetTextureFilter(textures.stone_pathway_diff, .POINT)
    rl.SetTextureFilter(textures.stone_pathway_disp, .POINT)  
    rl.SetTextureFilter(textures.stone_pathway_rough, .POINT) 

    // Cleanup Defers
    defer rl.UnloadTexture(textures.soldier) 
    defer rl.UnloadTexture(textures.stonewall)
    defer rl.UnloadTexture(textures.brownstonewall)
    defer rl.UnloadTexture(textures.brownstonewallwindow)
    defer rl.UnloadTexture(textures.door) 
    defer rl.UnloadTexture(textures.sky)
    defer rl.UnloadTexture(textures.stone_pathway_diff)
    defer rl.UnloadTexture(textures.stone_pathway_disp)
    defer rl.UnloadTexture(textures.stone_pathway_rough)

    // Skybox Setup
    skybox_mesh := rl.GenMeshSphere(1.0, 64, 64)
    skybox.skybox_model = rl.LoadModelFromMesh(skybox_mesh)
    skybox.skybox_model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = textures.sky
    skybox.sky_camera.fovy = 60.0
    skybox.sky_camera.projection = .PERSPECTIVE
    skybox.sky_camera.up = {0, 1, 0}
    defer rl.UnloadModel(skybox.skybox_model)

    target := rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)
    defer rl.UnloadRenderTexture(target)
    rl.SetTextureFilter(target.texture, .BILINEAR) 

    init_map_from_ascii()

    // --- 3. MAIN GAME LOOP ---
    for !rl.WindowShouldClose() 
    {
        // --- UPDATE ---
        dt := rl.GetFrameTime()
        time := f32(rl.GetTime())

        // Input & Logic
        if current_game_mode == .PLAYING_2D {
            update_puzzle(dt)
        } else {
            input(dt)
            update_doors(dt)
            
            // Effects
            torch_flicker = (math.sin(time * 10.0) * 0.5) + (math.sin(time * 25.0) * 0.3) 
            light_range : f32 = 10.0 + torch_flicker 

            // Camera Bob / Pitch
            base_bob := math.sin(walk_timer_for_headbob) * 4.0
            camera_dip := stop_shake * 2.5 
            total_v_offset := base_bob + camera_dip + look_pitch
            horizon := (WORLD_HEIGHT / 2) + i32(total_v_offset)

            // --- RENDER 3D VIEWPORT ---
            rl.BeginTextureMode(target)
            {
                rl.ClearBackground({130,20,20,255}) //blood red skies

                // 1. SKY
                draw_skybox_3d(&skybox, rl.Color{130, 20, 20, 255}, false)
                // 2. THE NEW FLOOR CALL
                // We pass the player variables so the floor knows where to look
                horizon := (WORLD_HEIGHT / 2) +i32(total_v_offset)
                //call dda row cast for floor
                draw_floor_rowcast_dda(&textures, player_pos, {dir_x, dir_y},{plane_x, plane_y}, horizon)

                            // 2. FLOOR (The "Layer Cake")
                            rl.BeginScissorMode(0, horizon, GAME_WIDTH, GAME_HEIGHT)
                            {
                                density : f32 = 4.0 
                                tex_x := player_pos.x * f32(textures.stone_pathway_diff.width)
                                tex_y := player_pos.y * f32(textures.stone_pathway_diff.height)
                                
                                src_rec := rl.Rectangle{ tex_x, tex_y, 1024, 1024 }
                                dst_rec := rl.Rectangle{ 0, f32(horizon), f32(GAME_WIDTH), f32(GAME_HEIGHT) }

                                // 1. DRAW THE REFLECTION FIRST (The Light)
                                reflection_alpha := i32(clamp(200 + torch_flicker * 40, 0, 255))
                               // draw_skybox_3d(&skybox, rl.Color{180, 40, 20, u8(reflection_alpha)}, true)

                                // 2. THE "GHOST BRICKS" (The Outline)
                                // We use the DISP (displacement/cracks) map as the main texture.
                                // We tint it so it's mostly transparent, leaving only the faint outlines.
                                rl.BeginBlendMode(.MULTIPLIED)
                                    rl.DrawTexturePro(textures.stone_pathway_disp, src_rec, dst_rec, {0,0}, 0, rl.Color{0, 0, 0, 255})
                                   // rl.DrawRectangle(0, horizon, GAME_WIDTH, GAME_HEIGHT, rl.Color{20, 20, 25, 40})
                                rl.EndBlendMode()
                            }
                            rl.EndScissorMode()

                // 3. WORLD
                draw_rays(light_range, total_v_offset) 
                draw_hud_background() 
                draw_sprites(light_range, total_v_offset) 
                draw_hud_foreground() 
            }
            rl.EndTextureMode()
        }

        // --- FINAL DRAWING (To Screen) ---
        rl.BeginDrawing()
            rl.ClearBackground(rl.BLACK)

            if current_game_mode == .PLAYING_2D {
                draw_puzzle() 
            } else {
                // Draw the 3D target upscaled
                src := rl.Rectangle{ 0, 0, f32(GAME_WIDTH), -f32(GAME_HEIGHT) }
                dst := rl.Rectangle{ 0, 0, f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT) }
                rl.DrawTexturePro(target.texture, src, dst, {0,0}, 0, rl.WHITE)
            }

            // Always overlay Minimap on top
            draw_minimap_hifi(1120, 640) 
        rl.EndDrawing()
    }

    fmt.println("Process Finished. Checking for leaks...")
}
//tint: rl.Color deleted from call
draw_skybox_3d :: proc(skybox: ^Skybox, tint: rl.Color, is_reflection:bool) // added floor reflection from skybox
{
    // If reflecting, we push the camera position "under" the floor
    // and invert the look direction for the vertical axis
    cam_pos := f32(0.5) //floor
    target_y := 2.5 + (look_pitch * 0.01) //floor
    // 1. Position stays on player
    if is_reflection {
        cam_pos = -0.5 // Move camera "underground"
        target_y = -2.5 - (look_pitch * 0.01) // Flip the vertical look
    }
    skybox.sky_camera.position = {player_pos.x, cam_pos, player_pos.y}
    // 2. THE TARGET FIX:
    // We add a +2.0 (or higher) constant to the Y target.
    // This shifts the "center" of the skybox up so you never see the bottom seam.
    skybox.sky_camera.target = {
        player_pos.x + dir_x, 
        target_y,
       // 2.5 + (look_pitch * 0.01), // Increased base height from 0.5 to 2.5 //pitch gone as added floor
        player_pos.y + dir_y,
    }

    rl.BeginMode3D(skybox.sky_camera)
    
        gl.DisableDepthMask()      
        gl.DisableBackfaceCulling() 
        
        // 3. THE TEXTURE SLIDE:
        // Rotate -20.0 degrees (adjust this number to slide the flashlight left)
        rotation_angle : f32 = 20
        
        // We use DrawModelEx to apply that rotation around the Y-axis
        // sky_camera_vec{0, 1, 0} 0.02 roll (was zero)
        rl.DrawModelEx(skybox.skybox_model, skybox.sky_camera.position, {0.0, 1, 0}, rotation_angle, -500.0, tint)
        
        gl.EnableBackfaceCulling()
        gl.EnableDepthMask()
        
    rl.EndMode3D()
}

init_map_from_ascii :: proc()
{
    trimmed_map := strings.trim_space(MAP_DATA)
    lines := strings.split(trimmed_map, "\n")
    defer delete(lines) 

    // Initialize metadata with -1 (meaning no door here)
    for i in 0..<MAP_COUNT do door_metadata[i] = -1

    for y in 0..<MAP_SIZE
    {
        if y >= len(lines) do break
        row := lines[y]
        
        for x in 0..<MAP_SIZE
        {
            if x >= len(row) do break
            
            char := row[x]
            idx := (y << 6) + x 
            
            switch char 
            {
                case '#': 
                    world_map[idx] = 1 // Greystone
                case 'B':      
                    world_map[idx] = 2 // Brownstone
                case 'W':
                    world_map[idx] = 3 // Window
                case 'D': // REGULAR DOOR
                {
                    if door_count < MAX_DOORS
                    {
                        world_map[idx] = 4 // Door ID
                        door_metadata[idx] = i32(door_count)
                        door_registry[door_count] = Door{
                            grid_pos = {i32(x), i32(y)},
                            type = .Regular,
                            state = .Closed,
                            is_active = true,
                        }
                        door_count += 1
                    }
                }
                case 'S': // SECRET WALL
                {
                    if door_count < MAX_DOORS
                    {
                        world_map[idx] = 99 // Secret wall ID
                        door_metadata[idx] = i32(door_count)
                        door_registry[door_count] = Door{
                            grid_pos = {i32(x), i32(y)},
                            type = .Secret,
                            state = .Closed,
                            is_active = true,
                        }
                        door_count += 1
                    }
                }
                case 'P':      
                    player_pos = {f32(x) + 0.5, f32(y) + 0.5}
                    world_map[idx] = 0 
                case 'E':
                    append(&enemies_dynamic_array, [2]f32{ f32(x) + 0.5, f32(y) + 0.5})
                    world_map[idx] = 0 
                case:          
                    world_map[idx] = 0 
            }
        }
    }
}

draw_sprites :: proc(light_range, total_v_offset: f32) 
{
    // 1. Moonlight colors for distance shading
    moonlight  := rl.Color{150, 150, 200, 255}
    night_void := rl.Color{10, 10, 30, 255} 

    // 2. GPU Masking (The Scissor)
    rl.BeginScissorMode(0, 0, i32(GAME_WIDTH), i32(WORLD_HEIGHT))

    for enemy in enemies_dynamic_array 
    {
        // 3. Distance & Position Logic
        sprite_x := enemy.x - player_pos.x
        sprite_y := enemy.y - player_pos.y

        inv_det := 1.0 / (plane_x * dir_y - dir_x * plane_y)
        transform_x := inv_det * (dir_y * sprite_x - dir_x * sprite_y)
        transform_y := inv_det * (-plane_y * sprite_x + plane_x * sprite_y) 

        // 4. Projection Math
        if transform_y > 0.1 
        {
            // Vertical: Use the Master Offset (Pitch + Bob)
            sprite_screen_y := (WORLD_HEIGHT / 2) + i32(total_v_offset)
            sprite_height := abs(i32(f32(WORLD_HEIGHT) / transform_y))

            // Horizontal: Center the sprite on screen
            sprite_screen_x := i32((GAME_WIDTH / 2) * (1 + transform_x / transform_y))

            draw_start_y := -sprite_height / 2 + sprite_screen_y
            draw_start_x := sprite_screen_x - sprite_height / 2
            draw_end_x   := sprite_screen_x + sprite_height / 2

            // 5. The Stripe Loop
            for stripe in draw_start_x..<draw_end_x
            {
                // Is the stripe on screen AND in front of the wall?
                if stripe >= 0 && stripe < GAME_WIDTH && transform_y < z_buffer[stripe]
                {
                    // Calculate texture X coordinate (0.0 to 1.0)
                    tex_x := i32(f32(stripe - draw_start_x) * f32(textures.soldier.width) / f32(sprite_height))
                    
                    source := rl.Rectangle{ f32(tex_x), 0, 1, f32(textures.soldier.height) }
                    
                    // Destination: We use draw_start_y directly because total_v_offset is already in it!
                    dest := rl.Rectangle{ 
                        f32(stripe), 
                        f32(draw_start_y), 
                        1, 
                        f32(sprite_height),
                    }

                    // Lighting math
                    sprite_brightness := math.clamp(1.0 - (transform_y / light_range), 0.0, 1.0)
                    sprite_shade := rl.ColorLerp(night_void, moonlight, sprite_brightness)

                    rl.DrawTexturePro(textures.soldier, source, dest, {0,0}, 0, sprite_shade)
                }
            }
        }
    }
    rl.EndScissorMode()
}



draw_hud_background :: proc()
{
    // Draw the gray bar
    rl.DrawRectangle(0, WORLD_HEIGHT, GAME_WIDTH, HUD_HEIGHT, rl.DARKGRAY)
    
}

draw_hud_foreground :: proc()
{
    rl.DrawText("HEALTH: 100%", 10, WORLD_HEIGHT + 10, 10, rl.WHITE)
    
}
update_doors :: proc(dt: f32)
{
    for i in 0..<door_count {
        d := &door_registry[i]
        if !d.is_active do continue

        switch d.state {
        case .Opening:
            d.offset += dt * 2.0
            if d.offset >= 1.0 { d.offset = 1.0; d.state = .Open; d.timer = 0.0 }
        case .Open:
            d.timer += dt
            if d.timer >= 3.0 do d.state = .Closing
        case .Closing:
            d.offset -= dt * 2.0
            if d.offset <= 0.0 { d.offset = 0.0; d.state = .Closed }
case .Moving: 
        {
            // 1. Keep track of where we started this specific 1-tile slide
            old_x := d.grid_pos.x
            old_y := d.grid_pos.y

            // 2. Smoothly increase offset (this is 0.0 to 1.0 for ONE tile)
            d.offset += dt * 1.0 
            
            // 3. Once the door has slid 1.0 units (one full tile)
            if d.offset >= 1.0 
            {
                new_x := old_x + d.move_dir.x
                new_y := old_y + d.move_dir.y
                
                new_idx := (new_y << 6) + new_x
                old_idx := (old_y << 6) + old_x

                // Check if the next spot is empty so we can keep moving
                if world_map[new_idx] == 0 
                {
                    // Move the "Solid" block in the map
                    world_map[old_idx] = 0
                    door_metadata[old_idx] = -1
                    
                    world_map[new_idx] = 99
                    door_metadata[new_idx] = i32(i)
                    
                    d.grid_pos = {new_x, new_y}
                    
                    // IMPORTANT: Subtract 1.0 rather than setting to 0
                    // This keeps the movement fluid if dt is large
                    d.offset -= 1.0 
                    
                    // Increase a separate counter to stop after 2 tiles
                    d.tiles_moved += 1 
                } 
                else 
                {
                    // Hit another wall? Stop moving.
                    d.offset = 0.0
                    d.state = .Finished
                }
            }

            if d.tiles_moved >= 2 {
                d.offset = 0.0 
                d.state = .Finished
            }
        }
        case .Closed: 
            break // Do nothing for normal closed doors

        case .Finished: 
        {
            // This runs once the Secret Wall (99) has finished sliding 2 tiles
            idx := (d.grid_pos.y << 6) + d.grid_pos.x
            world_map[idx] = 0        // Remove the wall from the map
            door_metadata[idx] = -1   // Clear the door ID from this spot
            d.is_active = false       // Stop updating this door entirely
        }
        } // End of switch
    }
}


get_map_cell :: proc(x, y: int) -> u8 //am I using this right. I declare it in dray_rays also.
{
    if x < 0 || x >= MAP_SIZE || y < 0 || y >= MAP_SIZE do return 0
    // We must explicitly cast the int from the array to u8
    return u8(world_map[(y << 6) + x])
}


draw_rays :: proc(light_range: f32, total_v_offset:f32) 
{
    wall_hit_x: f32 
    


    for x in 0..<GAME_WIDTH 
    {   
        camera_x : f32 = 2.0 * f32(x) / f32(GAME_WIDTH) - 1.0 // camera_x: maps pixel column to range -1 (left) to 1 (right)
        ray_dir_x := dir_x + plane_x * camera_x // Ray direction vectors: combining player direction and the camera plane
        ray_dir_y := dir_y + plane_y * camera_x

        map_x := int(player_pos.x) // Current tile the player is in
        map_y := int(player_pos.y)
        // delta_dist is the distance the ray travels to cross one full grid line
        // 1e30 is 1 followed by 30 zeros. pseudo Infinity for when ray_dir is 0
        delta_dist_x := math.abs(1.0 / ray_dir_x) if ray_dir_x != 0 else 1e30 //1 followed by 30 zeros. pseudo Infinity 
        delta_dist_y := math.abs(1.0 / ray_dir_y) if ray_dir_y != 0 else 1e30 //code will choose smallest number not 1e30 if player on straight line
        side_dist_x, side_dist_y, perp_wall_dist : f32 
        step_x, step_y : int
        hit, side : int = 0, 0 
        is_door_frame := false 
        
        // Calculate initial side_dist (distance from player pos to very first grid line)
        if (ray_dir_x < 0) {
            step_x = -1
            side_dist_x = (player_pos.x - f32(map_x)) * delta_dist_x
        } else {
            step_x = 1
            side_dist_x = (f32(map_x) + 1.0 - player_pos.x) * delta_dist_x
        }

        if (ray_dir_y < 0) {
            step_y = -1
            side_dist_y = (player_pos.y - f32(map_y)) * delta_dist_y
        } else {
            step_y = 1
            side_dist_y = (f32(map_y) + 1.0 - player_pos.y) * delta_dist_y
        }

        // --- DDA LOOP --- could add (hit == 0 || steps < 100) as 64x64 diagonal is about 90 so if map open/no walls loop stops.
        for (hit == 0 ) //ray hasn't hit a wall yet. If hit flag changes to 1 stops loop then repeats for next pixel
        {  
            if (side_dist_x < side_dist_y) { // the race: if x is shorter to cell jump to x; else jump to y
                side_dist_x += delta_dist_x
                map_x += step_x
                side = 0 
            } else {
                side_dist_y += delta_dist_y // else jump to y
                map_y += step_y
                side = 1 
            }
            // delta_dist is the distance to jump a full tile
            // side_dist is the distance of player pos. to the very first grid line either x or y.


            wall_type := get_map_cell(map_x, map_y)
            if wall_type == 0 do continue

            tile_idx := (map_y << 6) + map_x

            if wall_type == 4 {
                // --- THIN DOOR LOGIC ---
                door_id := door_metadata[tile_idx]
                if door_id != -1 {
                    d := &door_registry[door_id] 
                    dist_to_door := (side_dist_x - delta_dist_x * 0.5) if side == 0 else (side_dist_y - delta_dist_y * 0.5)
                    
                    // Check if we hit the door face before reaching the next tile edge
                    if (side == 0 && dist_to_door < side_dist_y) || (side == 1 && dist_to_door < side_dist_x) {
                        wall_hit := (player_pos.y + dist_to_door * ray_dir_y) if side == 0 else (player_pos.x + dist_to_door * ray_dir_x)
                        wall_hit_frac := wall_hit - math.floor(wall_hit)
                        // If the door is open (offset), check if the ray passes through the gap
                        if wall_hit_frac > d.offset {
                            perp_wall_dist = dist_to_door
                            wall_hit_x = wall_hit_frac - d.offset
                            hit = 1
                            is_door_frame = false
                        }
                    } else {
                        // HIT THE DOOR FRAME (The side of the wall slash the visible thickness of the wall)
                        is_door_frame = true
                        perp_wall_dist = (side_dist_x - delta_dist_x) if side == 0 else (side_dist_y - delta_dist_y)
                        wall_hit := (player_pos.y + perp_wall_dist * ray_dir_y) if side == 0 else (player_pos.x + perp_wall_dist * ray_dir_x)
                        wall_hit_x = wall_hit - math.floor(wall_hit)
                        hit = 1
                    }
                }
                                } else if wall_type == 99 { // --- SECRET PUSHWALL LOGIC ---
                        door_id := door_metadata[tile_idx]
                        if door_id != -1 {
                            d := &door_registry[door_id]
                            
                            // Calculate distance to the smoothly moving face
                            // We use d.offset to 'push' the hit plane back
                            dist_to_pushed_face := (side_dist_x - delta_dist_x + delta_dist_x * d.offset) if side == 0 else (side_dist_y - delta_dist_y + delta_dist_y * d.offset)

                            //  Only hit if the pushed face is closer than the next tile boundary
                            // This allows rays at sharp angles to hit the 'tunnel' sides correctly.
                            if (side == 0 && dist_to_pushed_face < side_dist_y) || (side == 1 && dist_to_pushed_face < side_dist_x) {
                                perp_wall_dist = dist_to_pushed_face
                                wall_hit := (player_pos.y + perp_wall_dist * ray_dir_y) if side == 0 else (player_pos.x + perp_wall_dist * ray_dir_x)
                                wall_hit_x = wall_hit - math.floor(wall_hit)
                                
                                // Adjust texture X so it doesn't 'slide' across the face, but stays pinned to the block
                                // This prevents the "long wall" stretching look
                                // Keep texture pinned to the moving wall
                                wall_hit_x -= d.offset 
                                
                                hit = 1
                                is_door_frame = false
                            } else {
                                // The ray would hit a side wall before reaching the pushed-back face.
                                // Do NOT set hit = 1; let the DDA loop continue naturally.
                                // Let DDA continue to hit the 'tunnel' sides
                                continue 
                            }
                        }
                    }
             else {
                // --- STANDARD WALL LOGIC ---
                //// perp_wall_dist avoids fisheye by projecting distance onto camera direction
                perp_wall_dist = (side_dist_x - delta_dist_x) if side == 0 else (side_dist_y - delta_dist_y)
                wall_hit := (player_pos.y + perp_wall_dist * ray_dir_y) if side == 0 else (player_pos.x + perp_wall_dist * ray_dir_x)
                wall_hit_x = wall_hit - math.floor(wall_hit)
                hit = 1
                is_door_frame = false
            }
        } // --- SUB-PROCEDURE CALL: RENDERING ---
        // Pass all the calculated data to a separate function to draw the column
         render_wall_column(x, perp_wall_dist, wall_hit_x, side, is_door_frame, light_range, map_x, map_y, ray_dir_x, ray_dir_y, total_v_offset)
    }
}   
    // --- Rendering ---
render_wall_column :: proc(x: int, 
    perp_wall_dist, wall_hit_x: f32, 
    side: int, 
    is_door_frame: bool, 
    light_range: f32, 
    map_x, map_y: int, 
    ray_dir_x, ray_dir_y, total_v_offset: f32) 
{
    // 1. Update Z-Buffer for sprite clipping
    z_buffer[x] = perp_wall_dist

    // 2. Calculate Height (f32 for smoother sub-pixel placement)
    // We use f32 to avoid the "stepping" look when looking up/down
    line_height := f32(WORLD_HEIGHT) / (perp_wall_dist if perp_wall_dist > 0.01 else 0.01)

    // 3. Vertical Placement
    // We calculate the start point relative to the viewport center
    draw_start := -line_height / 2.0 + (f32(WORLD_HEIGHT) / 2.0)

    // 4. Texture Selection (Simplified)
    tile_idx := (map_y << 6) + map_x
    w_type := world_map[math.clamp(tile_idx, 0, MAP_COUNT-1)]
    
    active_tex: rl.Texture2D
    if is_door_frame {
        active_tex = textures.stonewall 
    } else {
        switch w_type {
            case 4:      active_tex = textures.door 
            case 99, 2:  active_tex = textures.brownstonewall 
            case 3:      active_tex = textures.brownstonewallwindow
            case:        active_tex = textures.stonewall
        }
    }

    // 5. Texture X Mapping
    tex_x := i32(wall_hit_x * f32(active_tex.width))
    if (side == 0 && ray_dir_x > 0) || (side == 1 && ray_dir_y < 0) {
        tex_x = i32(active_tex.width) - tex_x - 1
    }

    // 6. Final Source & Destination
    // Source: One vertical strip of the texture
    source := rl.Rectangle{ f32(tex_x), 0, 1, f32(active_tex.height) }

    // Destination: Apply total_v_offset (Pitch + Bob + Dip)
    dest := rl.Rectangle{ 
        f32(x), 
        draw_start + total_v_offset, 
        1.0, 
        line_height,
    }

    // 7. Lighting
    brightness := math.clamp(1.0 - (perp_wall_dist / light_range), 0.0, 1.0)
    sky_color := rl.Color{10, 10, 30, 255}
    wall_color := rl.Color{150, 150, 200, 255}
    final_color := rl.ColorLerp(sky_color, wall_color, brightness)

    if side == 1 do final_color = rl.ColorBrightness(final_color, -0.2)
    if is_door_frame do final_color = rl.ColorBrightness(final_color, -0.5)

    // 8. Draw
    rl.DrawTexturePro(active_tex, source, dest, {0,0}, 0, final_color)

    
}

draw_floor_rowcast_dda :: proc(textures: ^GameTextures, player_pos: rl.Vector2, dir: rl.Vector2, plane: rl.Vector2, horizon: i32)
{
    // We only need to render from the horizon to the bottom of the screen
    for y in horizon..<GAME_HEIGHT
    {
        // 1. Calculate the distance from the camera to the floor for this row
        // 'p' is the vertical distance from the center of the screen
        p := f32(y - horizon)
        if p == 0 do continue // Avoid division by zero at the horizon
        
        // cam_z is the height of the camera (0.5 means middle of the tile)
        cam_z := 0.5 * f32(GAME_HEIGHT)
        row_dist := cam_z / p

        // 2. Find the world coordinates of the far-left and far-right rays
        // These are the "Floor Start" and "Floor End" points for this specific horizontal line
        floor_x_step := row_dist * (dir.x + plane.x - (dir.x - plane.x)) / f32(GAME_WIDTH)
        floor_y_step := row_dist * (dir.y + plane.y - (dir.y - plane.y)) / f32(GAME_WIDTH)

        floor_x := player_pos.x + row_dist * (dir.x - plane.x)
        floor_y := player_pos.y + row_dist * (dir.y - plane.y)

        
        // 3. Draw the row (Pixel by Pixel or using a optimized line draw)
        for x in 0..<GAME_WIDTH
        {
            // Get the tile coordinates (integer part)
            tx := int(floor_x) & (MAP_SIZE - 1)
            ty := int(floor_y) & (MAP_SIZE - 1)

            // Get the texture coordinates (fractional part)
            // This is the "Locked" part—it uses the world position to pick the pixel
            tex_u := int((floor_x - f32(int(floor_x))) * 1024) & 1023
            tex_v := int((floor_y - f32(int(floor_y))) * 1024) & 1023

            // Move to the next pixel's world position
            floor_x += floor_x_step
            floor_y += floor_y_step

            // Temporary Test: Draw a single line for the whole row 
            // using the color of the first pixel in that row
            // test_color := rl.Color{u8(row_dist * 20), 40, 30, 255} 
            // rl.DrawLine(0, y, GAME_WIDTH, y, test_color)
            
            // Note: In real Odin/Raylib, you'd write this to a pixel buffer 
            // because rl.DrawPixel 320,000 times per frame is slow.
        }
    }
}
    

// 4K minimap
draw_minimap_hifi :: proc(mm_x, mm_y: i32)
{
    // 16 tiles * 25 pixels = 400x400 physical area
    tile_size  : i32 = 10
    map_size   : i32 = 160
    
    sector_x := i32(player_pos.x) / 16
    sector_y := i32(player_pos.y) / 16
    
    map_start_x := sector_x * 16
    map_start_y := sector_y * 16

    // --- START SCISSOR ---
    // This stops rays from drawing outside the minimap box
    rl.BeginScissorMode(mm_x, mm_y, map_size, map_size)

        // 1. Draw Background (Matched to tile area)
        rl.DrawRectangle(mm_x, mm_y, map_size, map_size, rl.Color{0, 0, 0, 200}) //was 255

        // 2. DRAW THE TILES
        for y in 0..<16
        {
            for x in 0..<16
            {
                curr_x := map_start_x + i32(x) //curr == Current Map Coordinates
                curr_y := map_start_y + i32(y)

                if (curr_x >= 0 && curr_x < 64 && curr_y >= 0 && curr_y < 64)
                {
                    wall_id := world_map[(curr_y << 6) + curr_x]
                    
                    if (wall_id > 0)
                    {
                        draw_x := mm_x + (i32(x) * tile_size)
                        draw_y := mm_y + (i32(y) * tile_size)

                        wall_color: rl.Color
                        switch (wall_id)
                        {
                            case 1:  wall_color = rl.GRAY
                            case 2:  wall_color = rl.BROWN
                            case 3:  wall_color = rl.SKYBLUE
                            case:    wall_color = rl.DARKGRAY
                        }

                        // tile_size - 1 creates that sharp 4K grid line effect
                        rl.DrawRectangle(draw_x, draw_y, tile_size - 1, tile_size - 1, wall_color)
                    }
                }
            }
        }

        // 3. DRAW THE TORCH RAYS
        rel_p_x := player_pos.x - f32(map_start_x)
        rel_p_y := player_pos.y - f32(map_start_y)

        p_mm_x := f32(mm_x) + (rel_p_x * f32(tile_size))
        p_mm_y := f32(mm_y) + (rel_p_y * f32(tile_size))

        num_rays := 30 
        for i in 0..<num_rays
        {
            camera_x := 2.0 * f32(i) / f32(num_rays - 1) - 1.0
            r_dir_x  := dir_x + plane_x * camera_x
            r_dir_y  := dir_y + plane_y * camera_x

            map_check_x := i32(player_pos.x)
            map_check_y := i32(player_pos.y)
            
            delta_dist_x := abs(1.0 / r_dir_x) if r_dir_x != 0 else 1e30
            delta_dist_y := abs(1.0 / r_dir_y) if r_dir_y != 0 else 1e30
            
            side_dist_x, side_dist_y : f32
            step_x, step_y : i32

            if (r_dir_x < 0) 
            {
                step_x = -1
                side_dist_x = (player_pos.x - f32(map_check_x)) * delta_dist_x
            } 
            else 
            {
                step_x = 1
                side_dist_x = (f32(map_check_x) + 1.0 - player_pos.x) * delta_dist_x
            }

            if (r_dir_y < 0) 
            {
                step_y = -1
                side_dist_y = (player_pos.y - f32(map_check_y)) * delta_dist_y
            } 
            else 
            {
                step_y = 1
                side_dist_y = (f32(map_check_y) + 1.0 - player_pos.y) * delta_dist_y
            }

            dist : f32 = 0
            hit_id : i32 = 0
            for (dist < 16.0) // can increase. Ray only needs to cover the 16-tile sector
            {
                if (side_dist_x < side_dist_y) 
                {
                    dist = side_dist_x
                    side_dist_x += delta_dist_x
                    map_check_x += step_x
                } 
                else 
                {
                    dist = side_dist_y
                    side_dist_y += delta_dist_y
                    map_check_y += step_y
                }

                if (map_check_x >= 0 && map_check_x < 64 && map_check_y >= 0 && map_check_y < 64)
                {
                    hit_id = i32(world_map[(map_check_y << 6) + map_check_x])
                    if (hit_id > 0) do break
                }
                else do break
            }

            ray_color: rl.Color
            switch (hit_id)
            {
                case 1: ray_color = rl.GRAY
                case 2: ray_color = rl.BROWN
                case 3: ray_color = rl.SKYBLUE
                case:   ray_color = rl.DARKGREEN
            }
            ray_color.a = 150 

            end_x := p_mm_x + (r_dir_x * dist * f32(tile_size))
            end_y := p_mm_y + (r_dir_y * dist * f32(tile_size))
            rl.DrawLineEx({p_mm_x, p_mm_y}, {end_x, end_y}, 1, ray_color) //change to 1.5 or 2 for thinker lines.
        }

        // 4. Player Blip //minimap player circle
        rl.DrawCircleV({p_mm_x, p_mm_y}, 2, rl.GREEN)

    rl.EndScissorMode()
    // --- END SCISSOR ---
}

input :: proc(dt: f32)
{
    //game mode
    if rl.IsKeyPressed(.TAB)
    {
        if current_game_mode == .PLAYING_3D do current_game_mode = .PLAYING_2D
        else do current_game_mode = .PLAYING_3D
    }
    if current_game_mode == .PLAYING_2D
    {
        update_puzzle(dt)
        return
    }
        else
        {
        //------------------------------------3D input---------------------------------------------
        // --- 1. SETTINGS ---
        rot_speed    : f32 = 5.0 * dt
        max_speed    : f32 = 7.0 
        strafe_max   : f32 = 9.0   
        acceleration : f32 = 12.0 
        friction     : f32 = 18.0  
        mouse_sensitivity: f32 = 0.15
        buffer       : f32 = 0.2 // don't make camera too small or will be inside door

        forward_input := f32(0.0) 
        strafe_input  := f32(0.0)

        if (rl.IsKeyDown(.W)) do forward_input += 1.0
        if (rl.IsKeyDown(.S)) do forward_input -= 1.0
        
        // SWAPPED: A now adds, D now subtracts to fix your inversion
        if (rl.IsKeyDown(.A)) do strafe_input  -= 1.0 
        if (rl.IsKeyDown(.D)) do strafe_input  += 1.0

        // --- 2. ROTATION ---
        mouse_delta := rl.GetMouseDelta()
        rot_amount := +mouse_delta.x * mouse_sensitivity * dt

        if (rl.IsKeyDown(.LEFT))  do rot_amount -= rot_speed
        if (rl.IsKeyDown(.RIGHT)) do rot_amount += rot_speed


        //---------------------------input(dt) lookup and look down -------------
            // Arrow Keys
        if rl.IsKeyDown(.UP) do look_pitch += 400.0 * dt
        if rl.IsKeyDown(.DOWN) do look_pitch -= 400.0 * dt
        // Mouse (Optional)
        look_pitch -= mouse_delta.y * 0.5 // Sensitivity
        // Clamp it so you don't look too far and break the illusion
        look_pitch = math.clamp(look_pitch, -116.0, 98.0)
        //---------------------------------------------------------------------

        old_dir_x := dir_x
        dir_x = dir_x * math.cos(rot_amount) - dir_y * math.sin(rot_amount)
        dir_y = old_dir_x * math.sin(rot_amount) + dir_y * math.cos(rot_amount)
        
        old_plane_x := plane_x
        plane_x = plane_x * math.cos(rot_amount) - plane_y * math.sin(rot_amount)
        plane_y = old_plane_x * math.sin(rot_amount) + plane_y * math.cos(rot_amount)

        // --- 3. MOMENTUM ---
        if forward_input != 0 {
            player_vel += forward_input * acceleration * dt
        } else {
            if player_vel > 0 {
                player_vel -= friction * dt
                if player_vel < 0 do player_vel = 0
            } else if player_vel < 0 {
                player_vel += friction * dt
                if player_vel > 0 do player_vel = 0
            }
        }
        player_vel = math.clamp(player_vel, -max_speed, max_speed)

        if strafe_input != 0 {
            strafe_vel += strafe_input * acceleration * dt
        } else {
            if strafe_vel > 0 {
                strafe_vel -= friction * dt
                if strafe_vel < 0 do strafe_vel = 0
            } else if strafe_vel < 0 {
                strafe_vel += friction * dt
                if strafe_vel > 0 do strafe_vel = 0
            }
        }
        strafe_vel = math.clamp(strafe_vel, -strafe_max, strafe_max)

    // --- 4. COLLISION & MOVEMENT ---
        move_x := (dir_x * player_vel + plane_x * strafe_vel) * dt
        move_y := (dir_y * player_vel + plane_y * strafe_vel) * dt

        if math.abs(player_vel) > 0.1 || math.abs(strafe_vel) > 0.1 {
            walk_timer_for_headbob += dt * 10.0
        }

        // --- X Collision ---
        check_x := player_pos.x + move_x + (buffer if move_x > 0 else -buffer)
        check_x_idx := (int(player_pos.y) << 6) + int(check_x)
        wall_x := world_map[check_x_idx]
        can_move_x := false

        if wall_x == 0 {
            can_move_x = true
        } else if wall_x == 4 || wall_x == 99 {
            d_id := door_metadata[check_x_idx]
            // Door is passable if Open, Finished sliding, or 90% of the way there
            if d_id != -1 && (door_registry[d_id].state == .Open || 
                            door_registry[d_id].state == .Finished || 
                            door_registry[d_id].offset > 0.9) {
                can_move_x = true
            }
        }
        if can_move_x do player_pos.x += move_x

        // --- Y Collision ---
        check_y := player_pos.y + move_y + (buffer if move_y > 0 else -buffer)
        check_y_idx := (int(check_y) << 6) + int(player_pos.x)
        wall_y := world_map[check_y_idx]
        can_move_y := false

        if wall_y == 0 {
            can_move_y = true
        } else if wall_y == 4 || wall_y == 99 {
            d_id := door_metadata[check_y_idx]
            if d_id != -1 && (door_registry[d_id].state == .Open || 
                            door_registry[d_id].state == .Finished || 
                            door_registry[d_id].offset > 0.9) { // to not get stuck on door close
                can_move_y = true
            }
        }
        if can_move_y do player_pos.y += move_y

        // --- 5. INTERACTION (SPACE) ---
        if rl.IsKeyPressed(.SPACE) {
            tx := int(player_pos.x + dir_x * 1.0)
            ty := int(player_pos.y + dir_y * 1.0)
            idx := (ty << 6) + tx
            
            if idx >= 0 && idx < MAP_COUNT {
                door_id := door_metadata[idx]
                if door_id != -1 {
                    d := &door_registry[door_id]
                    if d.state == .Closed {
                        if d.type == .Regular {
                            d.state = .Opening
                        } else {
                            d.state = .Moving
                            if math.abs(dir_x) > math.abs(dir_y) {
                                d.move_dir = { i32(1) if dir_x > 0 else i32(-1), 0 }
                            } else {
                                d.move_dir = { 0, i32(1) if dir_y > 0 else i32(-1) }
                            }
                        }
                    }
                }
            }
        }
    }
}




