%Loading Custom Audio
[raw_audio, fs] = audioread('song_sample.mp3'); 

%Converting Stereo (2 channels) to Mono (1 channel)
if size(raw_audio, 2) == 2
    clean_audio = mean(raw_audio, 2)'; 
else
    clean_audio = raw_audio'; 
end

% Crop to the first 5 seconds to keep processing fast
max_samples = 5 * fs; 
if length(clean_audio) > max_samples
    clean_audio = clean_audio(1:max_samples);
end

N = length(clean_audio); 


fprintf('Playing Original Clean Audio.\n');
sound(clean_audio, fs);
pause(N/fs + 1); 

%Additive White Gaussian Noise (AWGN)
noise_power = 0.05; 
noise = noise_power * randn(1, N);
noisy_audio = clean_audio + noise;


fprintf('Playing Corrupted (Noisy) Audio.\n');
sound(noisy_audio, fs);
pause(N/fs + 1);


%Spectral Analysis (FFT)
% Computing Fast Fourier Transform to analyze the frequency spectrum
fft_noisy = fft(noisy_audio);

% Calculating the two-sided spectrum and then the single-sided magnitude spectrum
P2 = abs(fft_noisy / N);
P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2 * P1(2:end-1);

% Defining the frequency axis
f = fs * (0:(N/2)) / N;


fft_clean=fft(clean_audio);
P2_clean=abs(fft_clean / N);
P1_clean = P2_clean(1:floor(N/2)+1);
P1_clean(2:end-1) = 2 * P1_clean(2:end-1);

figure;
subplot(1,2,1);
plot(f, P1_clean, 'b');
title('Single-Sided Magnitude Spectrum of clean Audio');
xlabel('Frequency (Hz)');
ylabel('|Magnitude|');
grid on;


subplot(1,2,2);
plot(f, P1, 'b');
title('Single-Sided Magnitude Spectrum of Noisy Audio');
xlabel('Frequency (Hz)');
ylabel('|Magnitude|');
grid on;



%Dynamic Filter Design
%Calculating the Power Spectrum of the clean audio
fft_clean = fft(clean_audio);
P2_clean = abs(fft_clean / N).^2;
P1_clean = P2_clean(1:floor(N/2)+1);
P1_clean(2:end-1) = 2 * P1_clean(2:end-1);

%Calculating the Cumulative Energy to find the 95% bandwidth point
total_energy = sum(P1_clean);
cumulative_energy = cumsum(P1_clean);


cutoff_idx = find(cumulative_energy >= 0.95 * total_energy, 1);


f=fs*(0:(N/2))/N;
fc=f(cutoff_idx); 


fprintf('\n--- Filter Design ---\n');
fprintf('Dynamically calculated Cutoff Frequency: %.2f Hz\n', fc);


nyquist = fs / 2; 

if fc >= nyquist
    fc = nyquist - 1;
end
Wn = fc / nyquist; 

%Design IIR Low-Pass Filter (6th-order Butterworth)
[b_iir,a_iir]=butter(6,Wn,'low');

%Design FIR Low-Pass Filter (50th-order Windowed)
order_fir = 50;
b_fir = fir1(order_fir, Wn, 'low');
a_fir = 1;

%Signal Reconstruction
% We use 'filtfilt' (Zero-Phase Filtering) instead of 'filter'. This runs the filter forward and backward to prevent phase shifting/delay

denoised_iir = filtfilt(b_iir, a_iir, noisy_audio);
denoised_fir = filtfilt(b_fir, a_fir, noisy_audio);

%Scaling to ensure that denoised audio volume matches the clean audio volume
denoised_fir = denoised_fir*(max(abs(clean_audio))/max(abs(denoised_fir)));
denoised_iir = denoised_iir*(max(abs(clean_audio))/max(abs(denoised_iir)));


fprintf('Playing FIR Denoised Audio.\n');
sound(denoised_fir, fs);
pause(N/fs + 1);



fprintf('Playing IIR Denoised Audio.\n');
sound(denoised_iir, fs);
pause(N/fs + 1);


%Quantitative Analysis (SNR Calculation)

%Calculate the average power of the original clean audio
signal_power = sum(clean_audio.^2) / N;

%Calculate the power of the original injected noise
original_noise_power = sum((noisy_audio - clean_audio).^2) / N;

%Calculate the power of the residual noise left OVER after filtering
iir_noise_power = sum((denoised_iir - clean_audio).^2) / N;
fir_noise_power = sum((denoised_fir - clean_audio).^2) / N;


snr_original = 10 * log10(signal_power / original_noise_power);
snr_iir = 10 * log10(signal_power / iir_noise_power);
snr_fir = 10 * log10(signal_power / fir_noise_power);


fprintf('\n SNR Results\n');
fprintf('Original Noisy Signal SNR: %6.2f dB\n', snr_original);
fprintf('After IIR Filter SNR:      %6.2f dB (Improvement: +%.2f dB)\n', snr_iir, snr_iir - snr_original);
fprintf('After FIR Filter SNR:      %6.2f dB (Improvement: +%.2f dB)\n', snr_fir, snr_fir - snr_original);
