-- v0.7.0 bisect stub: Recipes tab/system not present in this era.
GemOrderTest = GemOrderTest or {}

function GemOrderTest_ShouldShareRecipes()
    return false
end

function GemOrderTest_ShareWorkshopRecipes()
end

function GemOrderTest_WorkshopHasRecipeForGem()
    return true
end

function GemOrderTest_GetRecipeCoverage()
    return {}
end

function GemOrderTest_ApplyRecipeReport()
end

function GemOrderTest_OnRecipesRefreshClick()
end
