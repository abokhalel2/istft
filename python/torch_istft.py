import numpy as np
import torch
from librosa.output import write_wav
import wav_file

win_length = 4096
hop_length = 1024
win = torch.hann_window(win_length)
saveFile = torch.istft(wav_file.arr, win_length, hop_length=hop_length, window=win)

write_wav('out.wav', np.asfortranarray(saveFile.squeeze().numpy()), 44100)
