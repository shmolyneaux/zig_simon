const ray = @cImport({
    @cInclude("raylib.h");
});

const emscripten = @cImport({
    @cInclude("emscripten/emscripten.h");
});

const std = @import("std");

const Scene = enum {
    click_to_start,
    main_menu,
    game,
    credits,
    score,
};

const font_size = 40;

fn rectangle_expand(rect: ray.Rectangle, amount: f32) ray.Rectangle {
    return .{
        .x=rect.x-amount,
        .y=rect.y-amount,
        .width=rect.width + 2*amount,
        .height=rect.height + 2*amount,
    };
}

fn drawTextCentered(text: anytype, x: i32, y: i32, size: i32, color: ray.Color) void {
    const text_width: i32 = ray.MeasureText(text, size);
    ray.DrawText(
        text,
        x - @divTrunc(text_width, 2),
        y - @divTrunc(size,2),
        size,
        color
    );
}

const State = struct {
    score: u8,
};

fn initializeIO() void {
    emscripten.emscripten_run_script(
        \\ shm_io_initialized = 0;
        \\ FS.mkdir('/data');
        \\ FS.mount(IDBFS, {}, '/data');
        \\ FS.syncfs(true, function (err) {
        \\     if (err) {
        \\          console.log("Startup error!", err);
        \\     } else {
        \\          console.log("IO Initialized");
        \\          shm_io_initialized = 42;
        \\     }
        \\ });
    );
}

fn isIOInitialized() bool {
    return emscripten.emscripten_run_script_int("shm_io_initialized") == 42;
}

fn loadState() State {
    const state_path = "/data/state";
    if (!ray.FileExists(state_path)) {
        ray.TraceLog(ray.LOG_INFO, "State not set, returning empty state");
        return .{.score=0};
    }

    // if (ray.GetFileLength(state_path)

    const state_data = ray.LoadFileData(state_path, 1);
    // check for null on state_data or something?

    const score = state_data[0];
    ray.UnloadFileData(state_data);

    var buffer: [256]u8 = undefined;
    const my_str = std.fmt.bufPrint(&buffer, "Loaded score {d}", .{score}) catch "Error loading score";
    ray.TraceLog(ray.LOG_INFO, my_str.ptr);

    return .{.score=score};
}

fn saveState(state: State) void {
    var buffer: [256]u8 = undefined;
    const my_str = std.fmt.bufPrint(&buffer, "Saving score {d}", .{state.score}) catch "Error saving score";
    ray.TraceLog(ray.LOG_INFO, my_str.ptr);

    const state_path = "/data/state";
    var file_data: [1]u8 = undefined;
    file_data[0] = state.score;

    if (!ray.SaveFileData(state_path, &file_data, 1)) {
        ray.TraceLog(ray.LOG_INFO, "Could not save score!");
    }

    emscripten.emscripten_run_script(
        \\ FS.syncfs(function (err) {
        \\     if (err) {
        \\          console.log("Shutdown error!", err);
        \\     }
        \\ });
    );
}

export fn main() void {
    const screenWidth = 800;
    const screenHeight = 450;

    ray.InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");
    ray.SetTargetFPS(60);
    ray.InitAudioDevice();

    initializeIO();

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Initializing...", 10, 10, 20, ray.LIGHTGRAY);
        ray.EndDrawing();
        if (isIOInitialized()) {
            break;
        }
    }

    // ray.TraceLog(ray.LOG_INFO, "Starting music");
    // const music = ray.LoadMusicStream("resources/after_the_rain.mp3");
    //ray.PlayMusicStream(music);

    const sound0 = ray.LoadSound("assets/drop_003.ogg");
    const sound1 = ray.LoadSound("assets/drop_003.ogg");
    const sound2 = ray.LoadSound("assets/drop_003.ogg");
    const sound3 = ray.LoadSound("assets/drop_003.ogg");

    // Frequencies of the notes of the pentatonic that are not the root note.
    // The sounds are pitched down by 0.725 so that the highest note isn't grating.
    ray.SetSoundPitch(sound0, 1.122462048309373 * 0.725);
    ray.SetSoundPitch(sound1, 1.259921049894873 * 0.725);
    ray.SetSoundPitch(sound2, 1.498307076876682 * 0.725);
    ray.SetSoundPitch(sound3, 1.681792830507429 * 0.725);

    var game_state = loadState();

    var scene = Scene.click_to_start;

    var order: [256]u8 = undefined;
    var orderMaxIdx: u8 = 0;
    var user_idx: u8 = 0;

    var sceneFirstFrame = true;

    var gameAnimStartTime: f64 = 0.0;

    var most_recent_score: u8 = 0;

    var score_scene_is_new_high_score = false;
    var score_scene_old_high_score: u8 = 0;

    var _scene_ignore_lastFrameTime = ray.GetTime();

    while (!ray.WindowShouldClose()) {
        const lastFrameTime = _scene_ignore_lastFrameTime;
        const currentFrameTime = ray.GetTime();

        const frameStartScene = scene;
        const mouse_pos = ray.GetMousePosition();

        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        switch (scene) {
            Scene.click_to_start => {
                drawTextCentered("Click anywhere to begin", screenWidth/2, screenHeight/2, font_size, ray.BLACK);
                if (ray.IsMouseButtonReleased(0)) {
                    scene = Scene.main_menu;
                }
            },
            Scene.main_menu => {
                const credits_text = "Credits";
                const credits_text_width: f32 = @floatFromInt(ray.MeasureText(credits_text, font_size));
                const credit_rect = .{.x = (screenWidth-credits_text_width)/2-5, .y=150 + font_size*1.5, .width=credits_text_width+10, .height=font_size+10};
                if (ray.CheckCollisionPointRec(mouse_pos, credit_rect)) {
                    ray.DrawRectangleRec(rectangle_expand(credit_rect, 5), ray.DARKBLUE);
                    ray.DrawRectangleRec(credit_rect, ray.BLUE);
                    if (ray.IsMouseButtonReleased(0)) {
                        scene = Scene.credits;
                    }
                } else {
                    ray.DrawRectangleRec(credit_rect, ray.BLUE);
                }
                ray.DrawText(credits_text, @intFromFloat(credit_rect.x+5), credit_rect.y+5, font_size, ray.BLACK);

                const start_text = "Start Game";
                const start_text_width: f32 = @floatFromInt(ray.MeasureText(start_text, font_size));
                const start_rect = .{.x = (screenWidth-start_text_width)/2-5, .y=150, .width=start_text_width+10, .height=font_size+10};
                if (ray.CheckCollisionPointRec(mouse_pos, start_rect)) {
                    ray.DrawRectangleRec(rectangle_expand(start_rect, 5), ray.DARKGREEN);
                    ray.DrawRectangleRec(start_rect, ray.GREEN);
                    if (ray.IsMouseButtonReleased(0)) {
                        scene = Scene.game;
                    }
                } else {
                    ray.DrawRectangleRec(start_rect, ray.GREEN);
                }
                ray.DrawText(start_text, @intFromFloat(start_rect.x+5), start_rect.y+5, font_size, ray.BLACK);

                var buffer: [256]u8 = undefined;
                const my_str = std.fmt.bufPrint(&buffer, "High Score: {d}", .{game_state.score}) catch "Error formatting score";
                ray.DrawText(my_str.ptr, 5, screenHeight - font_size - 5, font_size,  ray.BLACK);
            },
            Scene.game => {
                if (sceneFirstFrame) {
                    user_idx = 0;
                    orderMaxIdx = 1;
                    for (&order) |*value| {
                        value.* = @intCast(ray.GetRandomValue(0, 3));
                    }
                    gameAnimStartTime = currentFrameTime + 1.0;
                }

                const redGray = .{.r=229, .g=193, .b=197, .a=255};
                const greenGray = .{.r=192, .g=226, .b=199, .a=255};
                const blueGray = .{.r=203, .g=222, .b=239, .a=255};
                const yellowGray = .{.r=252, .g=251, .b=214, .a=255};

                const center = .{.x=screenWidth/2, .y=screenHeight/2};
                const tl = .{.x=0, .y=0};
                const tr = .{.x=screenWidth, .y=0};
                const br = .{.x=screenWidth, .y=screenHeight};
                const bl = .{.x=0, .y=screenHeight};
                ray.DrawTriangle(
                    center,
                    tr,
                    tl,
                    redGray,
                );
                ray.DrawTriangle(
                    center,
                    br,
                    tr,
                    greenGray,
                );
                ray.DrawTriangle(
                    center,
                    bl,
                    br,
                    blueGray,
                );
                ray.DrawTriangle(
                    center,
                    tl,
                    bl,
                    yellowGray,
                );

                ray.DrawCircle(screenWidth/2, 80, 55, .{.r= 190,.g= 22,.b= 35,.a= 255 });
                ray.DrawCircle(screenWidth - 80, screenHeight/2, 55, ray.DARKGREEN);
                ray.DrawCircle(screenWidth/2, screenHeight - 80, 55, ray.DARKBLUE);
                ray.DrawCircle(80, screenHeight/2, 55, .{.r= 191,.g=187,.b= 2,.a= 255 });

                // Play the next sound once a second
                const lastRes = std.math.modf(lastFrameTime - gameAnimStartTime);
                const curRes = std.math.modf(currentFrameTime - gameAnimStartTime);

                const idx: u8 = @intFromFloat(curRes.ipart);

                const show_pattern = currentFrameTime > gameAnimStartTime and idx < orderMaxIdx;

                if (currentFrameTime < gameAnimStartTime or show_pattern) {
                    drawTextCentered("Memorize", screenWidth/2, screenHeight/2, 40, ray.BLACK);
                }

                if (show_pattern) {
                    // There's a bug with this. Probably because it's overly complicated.
                    // Sometimes the first sound in the pattern doesn't play.
                    if (curRes.fpart < lastRes.fpart or lastFrameTime < gameAnimStartTime and gameAnimStartTime <= currentFrameTime) {
                        switch (order[idx]) {
                            0 => ray.PlaySound(sound0),
                            1 => ray.PlaySound(sound1),
                            2 => ray.PlaySound(sound2),
                            else => ray.PlaySound(sound3),
                        }
                    }

                    switch (order[idx]) {
                        0 => ray.DrawCircle(screenWidth/2, 80, 50, ray.RED),
                        1 => ray.DrawCircle(screenWidth - 80, screenHeight/2, 50, ray.GREEN),
                        2 => ray.DrawCircle(screenWidth/2, screenHeight - 80, 50, ray.BLUE),
                        else => ray.DrawCircle(80, screenHeight/2, 50, ray.YELLOW),
                    }
                } else if (currentFrameTime > gameAnimStartTime) {
                    var hover_tri: ?u8 = null;
                    if (ray.CheckCollisionPointTriangle(mouse_pos, center, tr, tl)) {
                        hover_tri = 0;
                        ray.DrawTriangleLines(center, tr, tl, ray.BLACK);
                    }
                    else if (ray.CheckCollisionPointTriangle(mouse_pos, center, br, tr)) {
                        hover_tri = 1;
                        ray.DrawTriangleLines(center, br, tr, ray.BLACK);
                    }
                    else if (ray.CheckCollisionPointTriangle(mouse_pos, center, bl, br)) {
                        hover_tri = 2;
                        ray.DrawTriangleLines(center, bl, br, ray.BLACK);
                    }
                    else if (ray.CheckCollisionPointTriangle(mouse_pos, center, tl, bl)) {
                        hover_tri = 3;
                        ray.DrawTriangleLines(center, tl, bl, ray.BLACK);
                    }

                    if (hover_tri) |tri| {
                        if (ray.IsMouseButtonReleased(0)) {
                            if (tri == order[user_idx]) {
                                switch (tri) {
                                    0 => ray.PlaySound(sound0),
                                    1 => ray.PlaySound(sound1),
                                    2 => ray.PlaySound(sound2),
                                    else => ray.PlaySound(sound3),
                                }
                                switch (tri) {
                                    0 => ray.DrawCircle(screenWidth/2, 80, 50, ray.RED),
                                    1 => ray.DrawCircle(screenWidth - 80, screenHeight/2, 50, ray.GREEN),
                                    2 => ray.DrawCircle(screenWidth/2, screenHeight - 80, 50, ray.BLUE),
                                    else => ray.DrawCircle(80, screenHeight/2, 50, ray.YELLOW),
                                }
                                user_idx += 1;

                                if (user_idx == orderMaxIdx) {
                                    user_idx = 0;
                                    orderMaxIdx += 1;
                                    gameAnimStartTime = currentFrameTime + 1.0;
                                }
                            } else {
                                ray.PlaySound(sound0);
                                ray.PlaySound(sound1);
                                ray.PlaySound(sound2);
                                ray.PlaySound(sound3);
                                most_recent_score = orderMaxIdx-1;
                                scene = Scene.score;
                            }
                        }
                    }
                }
            },
            Scene.score => {
                if (sceneFirstFrame) {
                    score_scene_old_high_score = game_state.score;
                    score_scene_is_new_high_score = false;

                    if (game_state.score < most_recent_score) {
                        score_scene_is_new_high_score = true;
                        game_state.score = most_recent_score;
                        saveState(game_state);
                    }
                }

                var buffer: [256]u8 = undefined;
                const my_str = std.fmt.bufPrint(&buffer, "Score: {d}", .{most_recent_score}) catch "Error showing score";
                drawTextCentered(my_str.ptr, screenWidth/2, screenHeight/2, 40, ray.BLACK);

                if (score_scene_is_new_high_score) {
                    const wave_offset: i32 = @intFromFloat(std.math.trunc(20.0*std.math.sin(ray.GetTime()*4.0)));
                    drawTextCentered("NEW HIGH SCORE!", screenWidth/2, screenHeight/2 - 100 + wave_offset, 50, ray.RED);

                    var buffer2: [256]u8 = undefined;
                    const str2 = std.fmt.bufPrint(&buffer2, "Old High Score: {d}", .{score_scene_old_high_score}) catch "Error showing score";
                    drawTextCentered(str2.ptr, screenWidth/2, screenHeight/2 + 50, 20, ray.BLACK);
                } else {
                    var buffer2: [256]u8 = undefined;
                    const str2 = std.fmt.bufPrint(&buffer2, "High Score: {d}", .{score_scene_old_high_score}) catch "Error showing score";
                    drawTextCentered(str2.ptr, screenWidth/2, screenHeight/2 + 50, 20, ray.BLACK);
                }

                drawTextCentered("Click to Return", screenWidth/2, screenHeight/2 + 150, 30, ray.BLACK);

                // TODO also wait for time to elapse
                if (ray.IsMouseButtonReleased(0)) {
                    scene = Scene.main_menu;
                }
            },
            Scene.credits => {
                drawTextCentered("Game by Stephen Molyneaux 2024", screenWidth/2, screenHeight/2, 40, ray.BLACK);
                drawTextCentered("Developed with Raylib - Copyright Ramon Santamaria (@raysan5)", screenWidth/2, screenHeight/2 + 40, 10, ray.BLACK);
                drawTextCentered("Click to Return", screenWidth/2, screenHeight/2 + 150, 20, ray.BLACK);

                if (ray.IsMouseButtonReleased(0)) {
                    scene = Scene.main_menu;
                }
            },
        }
        ray.EndDrawing();

        if (frameStartScene != scene) {
            sceneFirstFrame = true;
        } else {
            sceneFirstFrame = false;
        }
        _scene_ignore_lastFrameTime = ray.GetTime();
    }

    ray.CloseWindow();
}
