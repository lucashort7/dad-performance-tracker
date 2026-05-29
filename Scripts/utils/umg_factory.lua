local M = {}
local UEHelpers = require("UEHelpers")
local helpers = require("helpers.hud_helpers")

-- Caches for UMG Classes
local C = {
    UserWidget = nil,
    WidgetTree = nil,
    CanvasPanel = nil,
    Border = nil,
    TextBlock = nil,
    VerticalBox = nil,
    HorizontalBox = nil,
    KTextLib = nil,
}

local function InitCaches()
    C.UserWidget  = C.UserWidget  or StaticFindObject("/Script/UMG.UserWidget")
    C.WidgetTree  = C.WidgetTree  or StaticFindObject("/Script/UMG.WidgetTree")
    C.CanvasPanel = C.CanvasPanel or StaticFindObject("/Script/UMG.CanvasPanel")
    C.Border      = C.Border      or StaticFindObject("/Script/UMG.Border")
    C.TextBlock   = C.TextBlock   or StaticFindObject("/Script/UMG.TextBlock")
    C.VerticalBox = C.VerticalBox or StaticFindObject("/Script/UMG.VerticalBox")
    C.HorizontalBox = C.HorizontalBox or StaticFindObject("/Script/UMG.HorizontalBox")
    C.KTextLib    = C.KTextLib    or UEHelpers.GetKismetTextLibrary()
end

local function ToFText(str)
    if not C.KTextLib then return FText(str) end
    return C.KTextLib:Conv_StringToText(str)
end

function M.CreateHUD(name)
    InitCaches()
    local gi = UEHelpers.GetGameInstance()
    if not gi then return nil end

    local hud = StaticConstructObject(C.UserWidget, gi, FName(name))
    hud.WidgetTree = StaticConstructObject(C.WidgetTree, hud, FName(name .. "_Tree"))
    return hud
end

function M.CreateCanvas(tree, name)
    local canvas = StaticConstructObject(C.CanvasPanel, tree, FName(name))
    tree.RootWidget = canvas
    return canvas
end

function M.CreateVerticalBox(parent, name)
    return StaticConstructObject(C.VerticalBox, parent, FName(name))
end

function M.CreateHorizontalBox(parent, name)
    return StaticConstructObject(C.HorizontalBox, parent, FName(name))
end

function M.CreateTextBlock(parent, name, params)
    params = params or {}
    local tb = StaticConstructObject(C.TextBlock, parent, FName(name))
    if tb and tb:IsValid() then
        tb.Font.Size = params.size or 10
        tb.Font.SkewAmount = params.skew or 0
        tb:SetColorAndOpacity(params.color or helpers.FSlateColor(1,1,1,1))
        tb:SetShadowOffset(params.shadowOffset or {X = 1, Y = 1})
        tb:SetShadowColorAndOpacity(params.shadowColor or helpers.FLinearColor(0, 0, 0, 0))
        
        -- Handle Custom Font
        if params.fontPath then
            local fontObj = StaticFindObject(params.fontPath)
            if fontObj and fontObj:IsValid() then
                tb.Font.FontObject = fontObj
            end
        end

        -- Handle Outline
        if params.outline and params.outline.size and params.outline.size > 0 then
            tb.Font.OutlineSettings.OutlineSize = params.outline.size
            if params.outline.color then
                tb.Font.OutlineSettings.OutlineColor = params.outline.color
            end
        end

        if params.text then tb:SetText(ToFText(params.text)) end
        
        if parent.AddChild then parent:AddChild(tb) end
    end
    return tb
end

function M.CreateBorder(parent, name, params)
    params = params or {}
    local border = StaticConstructObject(C.Border, parent, FName(name))
    if border and border:IsValid() then
        border:SetBrushColor(params.brushColor or helpers.FLinearColor(0, 0, 0, 0.2))
        border:SetPadding(params.padding or {Left = 20, Top = 10, Right = 20, Bottom = 10})
        if params.content then border:SetContent(params.content) end
    end
    return border
end

function M.ApplyAlignment(canvas, widget, alignmentKey, customPos)
    local slot = canvas:AddChildToCanvas(widget)
    slot:SetAutoSize(true)
    local a = helpers.Alignments[alignmentKey] or helpers.Alignments.bottomleft
    slot:SetAnchors({Minimum = {X = a.anchor[1], Y = a.anchor[2]}, Maximum = {X = a.anchor[1], Y = a.anchor[2]}})
    slot:SetAlignment({X = a.align[1], Y = a.align[2]})
    
    local finalPos = customPos or {X = a.pos[1], Y = a.pos[2]}
    slot:SetPosition({X = finalPos.X, Y = finalPos.Y})
    return slot
end

function M.ToFText(str)
    InitCaches()
    return ToFText(str)
end

return M
