<?php

use App\Http\Controllers\FilesController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/files', [FilesController::class, 'index'])->name('files.index');

Route::post('/files/upload', [FilesController::class, 'upload'])->name('files.upload');

Route::get('/files/download/{file}', [FilesController::class, 'download'])->name('files.download');

Route::delete('/files/delete/{file}', [FilesController::class, 'destroy'])->name('files.destroy');

Route::get('/files/{file}', [FilesController::class, 'show'])->name('files.show');
