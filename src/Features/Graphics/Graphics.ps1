# Rendering settings that were sized for 2004 hardware. They go into the game's default settings
# (data/UVars.tgi, data/AVars.tgi); what the player changes in Options is saved separately
# (Documents/A&A/data/User/UVars.tgi) and still applies on top.

$script:GraphicsUserVars = [ordered]@{
  # off (the game's default): it upgrades TEXTURE shadows to PROJECTED, and infantry then cast
  # solid black boxes instead of their soft blob shadow. Set explicitly so installs that had it on
  # are switched back.
  ViewQualityExtreme                         = 'false'
  # terrain patches are pre-rendered into this pool; a patch covers ~640 screen px at 4K and
  # default zoom, so 128 px (and still 512) blurs the ground, and the HD ground only shows at 1024
  TerrainTexturePoolDesiredTextureResolution = '1024'
  TerrainTexturePoolMinTextureResolution     = '128'
  # projected shadows
  ShadowTexturePoolDesiredTextureResolution  = '256'
  ShadowTexturePoolMinTextureResolution      = '64'
  # HQ attachments and similar render-to-texture pieces
  GeneralTexturePoolDesiredTextureResolution = '512'
  # sun highlights on the ground (strength: AVars TerrainSpecular, 15%)
  TerrainSpecularEnabled                     = 'true'
  # "performance: extra whiz bangs" (units react to hits)
  HitAnimations                              = 'true'
  # particles generated, 1 = 100%: denser smoke, fire, dust and explosions
  ParticleGeneratePCG                        = '1.5'
}

$script:GraphicsAppVars = [ordered]@{
  # shadow colour = this share of the sun colour; lower is a deeper shadow
  DynamicShadowSunModulate = '0.4'
}

function Install-Graphics {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Rendering settings'
  Set-GameVars $Context 'UVars.tgi' $script:GraphicsUserVars
  Set-GameVars $Context 'AVars.tgi' $script:GraphicsAppVars
}

function Uninstall-Graphics {
  param([Parameter(Mandatory)]$Context)
  Write-Step 'Rendering settings: game defaults'
  Reset-GameVars $Context 'UVars.tgi' @($script:GraphicsUserVars.Keys)
  Reset-GameVars $Context 'AVars.tgi' @($script:GraphicsAppVars.Keys)
}
