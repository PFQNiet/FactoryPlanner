generator = {}

-- Returns the names of the recipes that shouldn't be included
local function undesirable_recipes()
    local undesirables = 
    {
        ["small-plane"] = false,
        ["electric-energy-interface"] = false,
        ["railgun"] = false,
        ["railgun-dart"] = false,
        ["player-port"] = false
    }

    -- Leaves loaders in if LoaderRedux is loaded
    if game.active_mods["LoaderRedux"] == nil then
        undesirables["loader"] = false
        undesirables["fast-loader"] = false
        undesirables["express-loader"] = false
    end
    
    return undesirables
end

-- Returns all standard recipes + custom mining recipes and space science recipe
function generator.all_recipes()
    local recipes = {}
    local undesirables = undesirable_recipes()

    -- Adding all standard recipes
    for name, recipe in pairs(game.forces.player.recipes) do
        if undesirables[name] ~= false and recipe.category ~= "handcrafting" then
            recipes[name] = recipe
        end
    end

    -- Adding all (solid) mining recipes
    -- (Inspired by https://github.com/npo6ka/FNEI/commit/58fef0cd4bd6d71a60b9431cb6fa4d96d2248c76)
    local function base_recipe()
        return {
            enabled = true,
            hidden = false,
            group = {name="intermediate_products", order="c"},
            subgroup = {name="mining", order="z"},
        }
    end

    for _, proto in pairs(game.entity_prototypes) do
        -- Adds all mining recipes. Only supports solids for now.
        if proto.mineable_properties and proto.resource_category and 
          proto.mineable_properties.products[1].type ~= "fluid" then
            local recipe = base_recipe()
            recipe.name = "impostor-" .. proto.name
            recipe.localised_name = proto.localised_name
            recipe.category = proto.resource_category
            -- Set energy to mining time so the forumla for the machine_count works out
            recipe.energy = proto.mineable_properties.mining_time
            recipe.ingredients = {{type="entity", name=proto.name, amount=1}}
            local products = proto.mineable_properties.products
            recipe.products = products
            if #products == 1 then recipe.item_type = products[1].type end
            recipe.order = proto.order

            if proto.mineable_properties.required_fluid then
                table.insert(recipe.ingredients, {
                    type = "fluid",
                    name = proto.mineable_properties.required_fluid,
                    amount = proto.mineable_properties.fluid_amount
                })
                recipe.category = "complex-solid"
            end

            recipes[recipe.name] = recipe
        end

        -- Adds unconditional extraction, like water pumps. Not sure if necessary/useful yet.
        --[[ if proto.fluid then
            local recipe = base_recipe()
            recipe.name = "impostor-" .. proto.fluid.name
            recipe.localised_name = proto.fluid.localised_name
            recipe.category = proto.resource_category
            recipe.ingredients = nil
            recipe.products = {{ type = 'fluid', name = proto.fluid.name, amount = 1 }}
            recipe.item_type = "fluid"
            recipe.order = proto.order

            recipes[recipe.name] = recipe
        end ]]
    end
    
    -- Adding convenient space science recipe
    recipes["fp-space-science-pack"] = {
        name = "fp-space-science-pack",
        localised_name = {"item-name.space-science-pack"},  -- official locale
        category = "rocket-building",
        enabled = false,
        hidden = false,
        energy = 0,
        group = {name="intermediate_products", order="c"},
        subgroup = {name="science-pack", order="g"},
        order = "k[fp-space-science-pack]",
        ingredients = {
            {type="item", name="rocket-part", amount=100},
            {type="item", name="satellite", amount=1}
        },
        products = {{type="item", name="space-science-pack", amount=1000}}
    }
 
    return recipes
end


-- Generates a table containing all machines for all categories
function generator.all_machines()
    local categories = {}
    
    local function generate_category_entry(category, proto)
        if categories[category] == nil then
            categories[category] = {machines = {}, order = {}}
        end
        local data = categories[category]
        
        -- If it is a miner, set speed to mining_speed so the machine_count formula works out
        local speed = proto.crafting_categories and proto.crafting_speed or proto.mining_speed
        local burner = proto.burner_prototype and true or false
        table.insert(data["order"], proto.name)
        local machine = {
            name = proto.name,
            localised_name = proto.localised_name,
            speed = speed,
            energy = proto.energy_usage,
            burner = burner,
            position = #data["order"]
        }
        data["machines"][proto.name] = machine
    end

    for _, proto in pairs(game.entity_prototypes) do
        if proto.crafting_categories and proto.name ~= "player" and proto.name ~= "escape-pod-assembler" then
            for category, enabled in pairs(proto.crafting_categories) do
                if enabled then generate_category_entry(category, proto) end
            end

        -- Adds mining machines
        elseif proto.resource_categories then
            for category, enabled in pairs(proto.resource_categories) do
                -- Only supports solid mining recipes for now (no oil etc)
                 if enabled and category ~= "basic-fluid" then
                    generate_category_entry(category, proto)

                    if category == "basic-solid" then
                        -- Add separate category for mining with fluids that avoids the burner-miner
                        if not proto.burner_prototype then generate_category_entry("complex-solid", proto) end
                    end
                end
            end
        end
    end

    return categories
end