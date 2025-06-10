function love.load()
    math.randomseed(os.time()) 

    love.window.setMode(0, 0, {fullscreen = true, resizable = false})
    love.window.setTitle("Cozy Sudoku") 
    
    LOCAL_GRID_SIZE = 540
    CELL_SIZE = LOCAL_GRID_SIZE / 9
    WIDTH = love.graphics.getWidth()
    HEIGHT = love.graphics.getHeight()
    OFFSET_X = (WIDTH - LOCAL_GRID_SIZE) / 2
    OFFSET_Y = (HEIGHT - LOCAL_GRID_SIZE) / 2

    BG_COLOR = {245/255, 245/255, 220/255, 1}
    MENU_COLOR = {211/255, 176/227, 227/255, 1}
    CELL_COLOR = {1, 1, 1, 1}
    GRID_COLOR = {0, 0, 0, 1}
    SELECTED_COLOR = {0, 0, 1, 1}
    CONFLICT_COLOR = {1, 0, 0, 1}
    FIXED_NUM_COLOR = {105/255, 167/255, 225/255, 1}
    USER_NUM_COLOR = {60/255, 60/255, 60/255, 1}
    TITLE_COLOR = {1, 1, 1, 1}
    TEXT_COLOR = {1, 1, 1, 1}
    OUTLINE_COLOR = {0, 0, 0, 1} 

    START_SCREEN = 0
    GAME_SCREEN = 1
    WIN_SCREEN = 2
    current_state = START_SCREEN

    title_font = love.graphics.newFont(80)
    win_font = love.graphics.newFont(100)
    menu_font = love.graphics.newFont(36)
    number_font = love.graphics.newFont(40)

    sample_board = {}
    editable = {}
    selected_row, selected_col = 0, 0
    conflict_cells = {}

    for i = 1, 9 do
        sample_board[i] = {}
        editable[i] = {}
        for j = 1, 9 do
            sample_board[i][j] = 0
            editable[i][j] = true
        end
    end

    need_redraw = true
    win_surface_cached = nil
    current_bg_color = generate_pastel_color()

    joystick = nil
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        joystick = joysticks[1]
    end

    using_controller = false
    left_trigger_pressed = false
    right_trigger_pressed = false

    track_paths = { 
        "music/blizzard-179280.mp3",
        "music/chill-night-154287.mp3",
        "music/fireplace-179281.mp3",
        "music/sunset-154292.mp3",
        "music/satisfying-lofi-for-focus-study-amp-working-242103.mp3",
        "music/lazy-time-summer-relax-lofi-199737.mp3",
    }

    currentTrackIndex = math.random(#track_paths)
    source = love.audio.newSource(track_paths[currentTrackIndex], "stream")
    source:setLooping(false) 
    love.audio.setVolume(0.5) 
    love.audio.play(source)
end

function generate_pastel_color()
    local r = math.random(180, 255) / 255
    local g = math.random(180, 255) / 255
    local b = math.random(180, 255) / 255
    return {r, g, b, 1}
end

function is_valid(grid, row, col, num)
    for x = 1, 9 do
        if grid[row][x] == num then
            return false
        end
    end
    for x = 1, 9 do
        if grid[x][col] == num then
            return false
        end
    end
    local start_row = 3 * math.floor((row - 1) / 3) + 1
    local start_col = 3 * math.floor((col - 1) / 3) + 1
    for i = 0, 2 do
        for j = 0, 2 do
            if grid[start_row + i][start_col + j] == num then
                return false
            end
        end
    end
    return true
end

function find_empty(grid)
    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] == 0 then
                return r, c
            end
        end
    end
    return nil, nil
end

function fill_grid(grid)
    local row, col = find_empty(grid)
    if not row then
        return true 
    end

    local nums = {1, 2, 3, 4, 5, 6, 7, 8, 9}
    for i = #nums, 2, -1 do
        local j = math.random(i)
        nums[i], nums[j] = nums[j], nums[i]
    end

    for _, num in ipairs(nums) do
        if is_valid(grid, row, col, num) then
            grid[row][col] = num
            if fill_grid(grid) then
                return true 
            end
            grid[row][col] = 0 
        end
    end
    return false 
end

function solve_sudoku(grid)
    local row, col = find_empty(grid)
    if not row then
        return 1 
    end

    local solutions_count = 0

    for num = 1, 9 do
        if is_valid(grid, row, col, num) then
            grid[row][col] = num
            solutions_count = solutions_count + solve_sudoku(grid)
            grid[row][col] = 0 

            if solutions_count > 1 then
                break 
            end
        end
    end
    return solutions_count
end

function generate_sudoku(cells_to_remove)
    cells_to_remove = cells_to_remove or 45 

    local grid = {}
    for i = 1, 9 do
        grid[i] = {}
        for j = 1, 9 do
            grid[i][j] = 0
        end
    end
    fill_grid(grid) 

    local all_cells = {}
    for r = 1, 9 do
        for c = 1, 9 do
            table.insert(all_cells, {r, c})
        end
    end
    for i = #all_cells, 2, -1 do
        local j = math.random(i)
        all_cells[i], all_cells[j] = all_cells[j], all_cells[i]
    end

    local puzzle = {}
    for i = 1, 9 do
        puzzle[i] = {}
        for j = 1, 9 do
            puzzle[i][j] = grid[i][j]
        end
    end
    
    local removed_count = 0
    
    for _, cell_coords in ipairs(all_cells) do
        if removed_count >= cells_to_remove then
            break
        end

        local r, c = cell_coords[1], cell_coords[2]
        local original_value = puzzle[r][c]
        puzzle[r][c] = 0 

        local temp_grid = {}
        for i = 1, 9 do
            temp_grid[i] = {}
            for j = 1, 9 do
                temp_grid[i][j] = puzzle[i][j]
            end
        end
        
        if solve_sudoku(temp_grid) == 1 then
            removed_count = removed_count + 1
        else
            puzzle[r][c] = original_value 
        end
    end
    
    return puzzle
end

function find_conflicts(grid)
    local conflicts = {}

    local function add_conflict(r, c)
        for _, coord in ipairs(conflicts) do
            if coord[1] == r and coord[2] == c then
                return
            end
        end
        table.insert(conflicts, {r, c})
    end

    for i = 1, 9 do
        local row_counts = {}
        for j = 1, 9 do
            local num = grid[i][j]
            if num ~= 0 then 
                row_counts[num] = row_counts[num] or {}
                table.insert(row_counts[num], {i, j})
            end
        end
        for num, coords in pairs(row_counts) do
            if #coords > 1 then 
                for _, coord in ipairs(coords) do
                    add_conflict(coord[1], coord[2])
                end
            end
        end

        local col_counts = {}
        for j = 1, 9 do
            local num = grid[j][i]
            if num ~= 0 then 
                col_counts[num] = col_counts[num] or {}
                table.insert(col_counts[num], {j, i})
            end
        end
        for num, coords in pairs(col_counts) do
            if #coords > 1 then 
                for _, coord in ipairs(coords) do
                    add_conflict(coord[1], coord[2])
                end
            end
        end
    end

    for box_row = 0, 2 do
        for box_col = 0, 2 do
            local box_counts = {}
            for i = 0, 2 do
                for j = 0, 2 do
                    local row, col = box_row * 3 + i + 1, box_col * 3 + j + 1
                    local num = grid[row][col]
                    if num ~= 0 then
                        box_counts[num] = box_counts[num] or {}
                        table.insert(box_counts[num], {row, col})
                    end
                end
            end
            for num, coords in pairs(box_counts) do
                if #coords > 1 then 
                    for _, coord in ipairs(coords) do
                        add_conflict(coord[1], coord[2])
                    end
                end
            end
        end
    end
    return conflicts
end

function check_win(grid)
    for r = 1, 9 do
        for c = 1, 9 do
            if grid[r][c] == 0 then
                return false
            end
        end
    end
    local conflicts = find_conflicts(grid)
    if #conflicts > 0 then
        return false
    end
    return true 
end

function draw_text_with_outline(font, text, color, outline_color, x, y, width, align, offset_x, offset_y)
    offset_x = offset_x or 2
    offset_y = offset_y or 2

    love.graphics.setFont(font)
    love.graphics.setColor(outline_color)
    love.graphics.printf(text, x - offset_x, y - offset_y, width, align)
    love.graphics.printf(text, x, y - offset_y, width, align)
    love.graphics.printf(text, x + offset_x, y - offset_y, width, align)
    love.graphics.printf(text, x - offset_x, y, width, align)
    love.graphics.printf(text, x + offset_x, y, width, align)
    love.graphics.printf(text, x - offset_x, y + offset_y, width, align)
    love.graphics.printf(text, x, y + offset_y, width, align)
    love.graphics.printf(text, x + offset_x, y + offset_y, width, align)
    
    love.graphics.setColor(color)
    love.graphics.printf(text, x, y, width, align)
end

function draw_start_screen()
    love.graphics.setColor(current_bg_color)
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

    draw_text_with_outline(title_font, "Cozy Sudoku", TITLE_COLOR, OUTLINE_COLOR, 0, HEIGHT/2 - 100, WIDTH, "center") 
    
    if using_controller then
        draw_text_with_outline(menu_font, "Press A/Start to Start", TEXT_COLOR, OUTLINE_COLOR, 0, HEIGHT - 100, WIDTH, "center")
        draw_text_with_outline(menu_font, "Press B/Select to Quit", TEXT_COLOR, OUTLINE_COLOR, 0, HEIGHT - 50, WIDTH, "center") 
    else
        draw_text_with_outline(menu_font, "Press Enter to Start", TEXT_COLOR, OUTLINE_COLOR, 0, HEIGHT - 100, WIDTH, "center")
        draw_text_with_outline(menu_font, "Press ESC to Quit", TEXT_COLOR, OUTLINE_COLOR, 0, HEIGHT - 50, WIDTH, "center")
    end
end

function draw_grid()
    love.graphics.setColor(current_bg_color)
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

    for row = 1, 9 do
        for col = 1, 9 do
            local x = OFFSET_X + (col - 1) * CELL_SIZE
            local y = OFFSET_Y + (row - 1) * CELL_SIZE
            
            love.graphics.setColor(CELL_COLOR)
            love.graphics.rectangle("fill", x, y, CELL_SIZE, CELL_SIZE)

            local num = sample_board[row][col]
            if num ~= 0 then
                local color = USER_NUM_COLOR
                local is_conflict = false
                for _, conflict_cell in ipairs(conflict_cells) do
                    if conflict_cell[1] == row and conflict_cell[2] == col then
                        is_conflict = true
                        break
                    end
                end

                if is_conflict then
                    color = CONFLICT_COLOR
                elseif not editable[row][col] then
                    color = FIXED_NUM_COLOR
                end
                
                love.graphics.setFont(number_font)
                love.graphics.setColor(color)
                love.graphics.printf(tostring(num), x, y + (CELL_SIZE - number_font:getHeight()) / 2, CELL_SIZE, "center")
            end

            if row == selected_row + 1 and col == selected_col + 1 then
                love.graphics.setColor(SELECTED_COLOR)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x, y, CELL_SIZE, CELL_SIZE)
                love.graphics.setLineWidth(1)
            end
        end
    end

    love.graphics.setColor(GRID_COLOR)
    for i = 0, 9 do
        local thickness = (i % 3 == 0) and 4 or 1 
        love.graphics.setLineWidth(thickness)
        love.graphics.line(OFFSET_X + i * CELL_SIZE, OFFSET_Y, OFFSET_X + i * CELL_SIZE, OFFSET_Y + LOCAL_GRID_SIZE) 
        love.graphics.line(OFFSET_X, OFFSET_Y + i * CELL_SIZE, OFFSET_X + LOCAL_GRID_SIZE, OFFSET_Y + i * CELL_SIZE) 
    end
    love.graphics.setLineWidth(1)
end

function create_win_surface()
    win_surface_cached = love.graphics.newCanvas(WIDTH, HEIGHT)
    love.graphics.setCanvas(win_surface_cached)

    love.graphics.setColor(0, 0, 0, 0.8) 
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
    
    love.graphics.setFont(win_font)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("You Win!", 0, HEIGHT/2 - 50, WIDTH, "center")

    love.graphics.setFont(menu_font)
    love.graphics.setColor(1, 1, 1, 1)
    if using_controller then
        love.graphics.printf("A/Start to Play Again | B/Select for Menu", 0, HEIGHT/2 + 50, WIDTH, "center") 
    else
        love.graphics.printf("Enter to Play Again | ESC for Menu", 0, HEIGHT/2 + 50, WIDTH, "center")
    end

    love.graphics.setCanvas() 
end

function draw_win_screen()
    if win_surface_cached == nil then
        create_win_surface()
    end
    love.graphics.draw(win_surface_cached, 0, 0)
end

function love.update(dt)
	if not source:isPlaying() then
        currentTrackIndex = math.random(#track_paths)
        source = love.audio.newSource(track_paths[currentTrackIndex], "stream")
        source:setLooping(false) 
        love.audio.play(source) 
    end
end

function love.draw()
    if current_state == START_SCREEN then
        draw_start_screen()
    elseif current_state == GAME_SCREEN then
        draw_grid()
    elseif current_state == WIN_SCREEN then
        draw_win_screen() 
    end
end

function love.joystickadded(j)
    if not joystick then
        joystick = j
    end
end

function love.joystickremoved(j)
    if joystick == j then
        joystick = nil
        local joysticks = love.joystick.getJoysticks()
        if #joysticks > 0 then
            joystick = joysticks[1]
        end
    end
end

function love.gamepadaxis(joystick_obj, axis, value)
    using_controller = true
    
    if current_state == GAME_SCREEN then
        if axis == "triggerleft" then
            if value > 0.5 and not left_trigger_pressed then 
                left_trigger_pressed = true
                if editable[selected_row + 1][selected_col + 1] then
                    local current_num = sample_board[selected_row + 1][selected_col + 1]
                    current_num = current_num - 1
                    if current_num < 0 then current_num = 9 end 
                    sample_board[selected_row + 1][selected_col + 1] = current_num
                    conflict_cells = find_conflicts(sample_board)
                    if check_win(sample_board) then
                        current_state = WIN_SCREEN
                        win_surface_cached = nil 
                    end
                end
            elseif value <= 0.1 and left_trigger_pressed then 
                left_trigger_pressed = false
            end
        elseif axis == "triggerright" then
            if value > 0.5 and not right_trigger_pressed then 
                right_trigger_pressed = true
                if editable[selected_row + 1][selected_col + 1] then
                    local current_num = sample_board[selected_row + 1][selected_col + 1]
                    current_num = current_num + 1
                    if current_num > 9 then current_num = 0 end 
                    sample_board[selected_row + 1][selected_col + 1] = current_num
                    conflict_cells = find_conflicts(sample_board)
                    if check_win(sample_board) then
                        current_state = WIN_SCREEN
                        win_surface_cached = nil 
                    end
                end
            elseif value <= 0.1 and right_trigger_pressed then 
                right_trigger_pressed = false
            end
        end
    end
end

function love.gamepadpressed(joystick_obj, button)
    using_controller = true
    need_redraw = true 

    if button == "b" or button == "back" or button == "select" then 
        if current_state == GAME_SCREEN or current_state == WIN_SCREEN then
            current_state = START_SCREEN 
            win_surface_cached = nil 
            current_bg_color = generate_pastel_color() 
        else 
            love.event.quit() 
        end
        return 
    end

    if current_state == GAME_SCREEN then
        if button == "dpup" then
            selected_row = math.max(0, selected_row - 1)
        elseif button == "dpdown" then
            selected_row = math.min(8, selected_row + 1)
        elseif button == "dpleft" then
            selected_col = math.max(0, selected_col - 1)
        elseif button == "dpright" then
            selected_col = math.min(8, selected_col + 1)
        elseif button == "leftshoulder" then
            if editable[selected_row + 1][selected_col + 1] then
                local current_num = sample_board[selected_row + 1][selected_col + 1]
                current_num = current_num - 1
                if current_num < 0 then current_num = 9 end
                sample_board[selected_row + 1][selected_col + 1] = current_num
            end
        elseif button == "rightshoulder" then
            if editable[selected_row + 1][selected_col + 1] then
                local current_num = sample_board[selected_row + 1][selected_col + 1]
                current_num = current_num + 1
                if current_num > 9 then current_num = 0 end
                sample_board[selected_row + 1][selected_col + 1] = current_num
            end
        end
        
        if button == "leftshoulder" or button == "rightshoulder" then
            conflict_cells = find_conflicts(sample_board)
            if check_win(sample_board) then
                current_state = WIN_SCREEN
                win_surface_cached = nil 
            end
        end
    end

    if current_state == START_SCREEN then
        if button == "start" or button == "a" then
            current_bg_color = generate_pastel_color()
            local new_board = generate_sudoku() 
            for r = 1, 9 do
                for c = 1, 9 do
                    sample_board[r][c] = new_board[r][c]
                    editable[r][c] = (new_board[r][c] == 0) 
                end
            end
            conflict_cells = {} 
            selected_row, selected_col = 4, 4 
            current_state = GAME_SCREEN 
            win_surface_cached = nil 
        end
    elseif current_state == WIN_SCREEN then
        if button == "start" or button == "a" then
            current_bg_color = generate_pastel_color()
            local new_board = generate_sudoku()
            for r = 1, 9 do
                for c = 1, 9 do
                    sample_board[r][c] = new_board[r][c]
                    editable[r][c] = (new_board[r][c] == 0)
                end
            end
            conflict_cells = {}
            selected_row, selected_col = 4, 4
            current_state = GAME_SCREEN
            win_surface_cached = nil
        end
    end
end

function love.joystickaxis(joystick_obj, axis, value)
end

function love.mousepressed(x, y, button)
    using_controller = false 
    if current_state == GAME_SCREEN and button == 1 then 
        local grid_x = x - OFFSET_X
        local grid_y = y - OFFSET_Y

        if grid_x >= 0 and grid_x < LOCAL_GRID_SIZE and grid_y >= 0 and grid_y < LOCAL_GRID_SIZE then
            selected_col = math.floor(grid_x / CELL_SIZE)
            selected_row = math.floor(grid_y / CELL_SIZE)
            need_redraw = true 
        end
    end
end

function love.keypressed(key)
    using_controller = false 
    need_redraw = true 
    
    if key == "escape" then
        if current_state == GAME_SCREEN or current_state == WIN_SCREEN then
            current_state = START_SCREEN 
            win_surface_cached = nil 
            current_bg_color = generate_pastel_color() 
        else 
            love.event.quit() 
        end
    end

    if current_state == START_SCREEN then
        if key == "return" then
            current_bg_color = generate_pastel_color()
            local new_board = generate_sudoku()
            for r = 1, 9 do
                for c = 1, 9 do
                    sample_board[r][c] = new_board[r][c]
                    editable[r][c] = (new_board[r][c] == 0)
                end
            end
            conflict_cells = {}
            selected_row, selected_col = 4, 4
            current_state = GAME_SCREEN
            win_surface_cached = nil
        end
    elseif current_state == GAME_SCREEN then
        if key == "up" then
            selected_row = math.max(0, selected_row - 1)
        elseif key == "down" then
            selected_row = math.min(8, selected_row + 1)
        elseif key == "left" then
            selected_col = math.max(0, selected_col - 1)
        elseif key == "right" then
            selected_col = math.min(8, selected_col + 1)
        elseif key:match("%d") then 
            local num_to_set = tonumber(key)
            if editable[selected_row + 1][selected_col + 1] then
                sample_board[selected_row + 1][selected_col + 1] = num_to_set
            end
        elseif key == "backspace" or key == "delete" then
            if editable[selected_row + 1][selected_col + 1] then
                sample_board[selected_row + 1][selected_col + 1] = 0 
            end
        end

        conflict_cells = find_conflicts(sample_board)
        if check_win(sample_board) then
            current_state = WIN_SCREEN
            win_surface_cached = nil 
        end
    elseif current_state == WIN_SCREEN then
        if key == "return" then
            current_bg_color = generate_pastel_color()
            local new_board = generate_sudoku()
            for r = 1, 9 do
                for c = 1, 9 do
                    sample_board[r][c] = new_board[r][c]
                    editable[r][c] = (new_board[r][c] == 0)
                end
            end
            conflict_cells = {}
            selected_row, selected_col = 4, 4
            current_state = GAME_SCREEN
            win_surface_cached = nil
        end
    end
end