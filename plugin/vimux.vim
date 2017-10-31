if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

command -nargs=* VimuxRunCommand :call VimuxRunCommand(<args>)
command VimuxRunLastCommand :call VimuxRunLastCommand()
command VimuxCloseRunner :call VimuxCloseRunner()
command VimuxZoomRunner :call VimuxZoomRunner()
command VimuxInspectRunner :call VimuxInspectRunner()
command VimuxScrollUpInspect :call VimuxScrollUpInspect()
command VimuxScrollDownInspect :call VimuxScrollDownInspect()
command VimuxInterruptRunner :call VimuxInterruptRunner()
command -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command VimuxClearRunnerHistory :call VimuxClearRunnerHistory()
command VimuxTogglePane :call VimuxTogglePane()

function! VimuxRunCommandInDir(command, useFile)
    let l:file = ""
    if a:useFile ==# 1
        let l:file = shellescape(expand('%:t'), 1)
    endif
    call VimuxRunCommand("(cd ".shellescape(expand('%:p:h'), 1)." && ".a:command." ".l:file.")")
endfunction

function! VimuxRunLastCommand()
  if exists("g:VimuxRunnerId")
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo "No last vimux command."
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !exists("g:VimuxRunnerId") || _VimuxHasRunner(g:VimuxRunnerId) == -1
    call VimuxOpenRunner()
  endif

  let l:autoreturn = 1
  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let resetSequence = _VimuxOption("g:VimuxResetSequence", "q C-u")
  let g:VimuxLastCommand = a:command

  call VimuxSendKeys(resetSequence)
  call VimuxSendText(a:command)

  if l:autoreturn == 1
    call VimuxSendKeys("Enter")
  endif
endfunction

function! VimuxSendText(text)
  call VimuxSendKeys('"'.escape(a:text, '\"$`').'"')
endfunction

function! VimuxSendKeys(keys)
  if exists("g:VimuxRunnerId")
    call _VimuxTmux("send-keys -t ".g:VimuxRunnerId." ".a:keys)
  else
    echo "No vimux runner pane/window. Create one with VimuxOpenRunner"
  endif
endfunction

function! VimuxOpenRunner()
  let nearestId = _VimuxNearestId()
  if _VimuxOption("g:VimuxUseNearest", 1) == 1 && nearestId != -1
    let g:VimuxRunnerId = nearestId
  else
    if _VimuxRunnerType() == "pane"
      let height = _VimuxOption("g:VimuxHeight", 20)
      let orientation = _VimuxOption("g:VimuxOrientation", "v")
      call _VimuxTmux("split-window -p ".height." -".orientation)
    elseif _VimuxRunnerType() == "window"
      call _VimuxTmux("new-window")
    endif
    let g:VimuxRunnerId = _VimuxTmuxId()
    call _VimuxTmux("last-"._VimuxRunnerType())
  endif
endfunction

function! VimuxCloseRunner()
  if exists("g:VimuxRunnerId")
    call _VimuxTmux("kill-"._VimuxRunnerType()." -t ".g:VimuxRunnerId)
    unlet g:VimuxRunnerId
  endif
endfunction

function! VimuxTogglePane()
  if exists("g:VimuxRunnerId")
    if _VimuxRunnerType() == "window"
        call _VimuxTmux("join-pane -d -s ".g:VimuxRunnerId." -p "._VimuxOption("g:VimuxHeight", 20))
        let g:VimuxRunnerType = "pane"
    elseif _VimuxRunnerType() == "pane"
		let g:VimuxRunnerId=substitute(_VimuxTmux("break-pane -d -t ".g:VimuxRunnerId." -P -F '#{window_index}'"), "\n", "", "")
        let g:VimuxRunnerType = "window"
    endif
  endif
endfunction

function! VimuxZoomRunner()
  if exists("g:VimuxRunnerId")
    if _VimuxRunnerType() == "pane"
      call _VimuxTmux("resize-pane -Z -t ".g:VimuxRunnerId)
    elseif _VimuxRunnerType() == "window"
      call _VimuxTmux("select-window -t ".g:VimuxRunnerId)
    endif
  endif
endfunction

function! VimuxInspectRunner()
  call _VimuxTmux("select-"._VimuxRunnerType()." -t ".g:VimuxRunnerId)
  call _VimuxTmux("copy-mode")
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call _VimuxTmux("last-"._VimuxRunnerType())
  call VimuxSendKeys("C-u")
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call _VimuxTmux("last-"._VimuxRunnerType())
  call VimuxSendKeys("C-d")
endfunction

function! VimuxInterruptRunner()
  call VimuxSendKeys("^c")
endfunction

function! VimuxClearRunnerHistory()
  if exists("g:VimuxRunnerId")
    call _VimuxTmux("clear-history -t ".g:VimuxRunnerId)
  endif
endfunction

function! VimuxPromptCommand(...)
  let command = a:0 == 1 ? a:1 : ""
  let l:command = input(_VimuxOption("g:VimuxPromptString", "Command? "), command)
  call VimuxRunCommand(l:command)
endfunction

function! _VimuxTmux(arguments)
  let l:command = _VimuxOption("g:VimuxTmuxCommand", "tmux")
  return system(l:command." ".a:arguments)
endfunction

function! _VimuxTmuxSession()
  return _VimuxTmuxProperty("#S")
endfunction

function! _VimuxTmuxId()
  if _VimuxRunnerType() == "pane"
    return _VimuxTmuxPaneId()
  else
    return _VimuxTmuxWindowId()
  end
endfunction

function! _VimuxTmuxPaneId()
  return _VimuxTmuxProperty("#D")
endfunction

function! _VimuxTmuxWindowId()
  return _VimuxTmuxProperty("#I")
endfunction

function! _VimuxNearestId()
  let views = split(_VimuxTmux("list-"._VimuxRunnerType()."s"), "\n")

  for view in views
    if match(view, "(active)") == -1
      return split(view, ":")[0]
    endif
  endfor

  return -1
endfunction

function! _VimuxRunnerType()
  return _VimuxOption("g:VimuxRunnerType", "pane")
endfunction

function! _VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! _VimuxTmuxProperty(property)
    return substitute(_VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! _VimuxHasRunner(index)
  return match(_VimuxTmux("list-"._VimuxRunnerType()."s -aF '#{pane_id}'"), a:index)
endfunction
