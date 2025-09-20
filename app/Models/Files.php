<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Files extends Model
{
    protected $fillable = [
        'name',
        'path',
    ];

    public function getPath(): string
    {
        return 'storage/' . $this->path;
    }
}
