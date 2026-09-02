import { HttpClient } from '@angular/common/http';
import { Component, OnInit, inject, signal } from '@angular/core';

interface Greeting {
  environment: string;
  generated_at: string;
  message: string;
  version: string;
}

@Component({
  selector: 'app-root',
  styleUrl: './app.scss',
  templateUrl: './app.html',
})
export class App implements OnInit {
  private readonly http = inject(HttpClient);

  protected readonly error = signal(false);
  protected readonly greeting = signal<Greeting | null>(null);

  ngOnInit(): void {
    this.http.get<Greeting>('/api/greeting').subscribe({
      error: () => this.error.set(true),
      next: (value) => this.greeting.set(value),
    });
  }
}
