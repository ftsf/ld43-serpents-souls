import sdl2.sdl
import opengl
import glm

var window: Window
var screenBufferFBO: GLuint
var screenBufferTexture: GLuint

proc initGL() =
  loadExtensions()
  discard glSetAttribute(opengl.GL_CONTEXT_PROFILE_MASK, GL_CONTEXT_PROFILE_CORE.cint)
  discard glSetAttribute(GL_CONTEXT_MAJOR_VERSION, 3.cint)
  discard glSetAttribute(GL_CONTEXT_MINOR_VERSION, 3.cint)

  var context = window.glCreateContext()

  glGenFramebuffers(1, screenBufferFBO.addr)
  glBindFramebuffer(GL_FRAMEBUFFER, screenBufferFBO)


proc reshape(w,h: int) =
  screenWidth = w
  screenHeight = h
  screenAspect = w.float / h.float

  glViewport(0,0,w,h)

  projection = perspective[float32](degtorad(45.0), screenAspect, 0.01, 1000.0)

  glGenTextures(1, screenBufferTexture.addr)
  glBindTexture(GL_TEXTURE_2D, screenBufferTexture)
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, screenWidth, screenHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, nil)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP)

  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, screenBufferTexture, 0)

  if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE:
    raise newException(Exception, "framebuffer not complete")

proc displayFramebuffer(texture: GLuint, depth: bool, x,y,w,h: float32) =
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, texture)
  debugShader.use()
  debugShader.setUniformBool("depth", depth)
  renderQuad(x,y,w,h)

proc render() =
  displayFramebuffer(screenBufferTexture, false, 0, 0, screenWidth*screenScale, screenHeight*screenScale)

proc createWindow3D*(title: string, w,h: int, scale: int = 2, fullscreen: bool = false) =
  screenWidth = w
  screenHeight = h
  screenScale = scale
  window = createWindow(title, 0, 0, w*scale, h*scale, WINDOW_OPENGL or WINDOW_RESIZABLE)

  initGL()
