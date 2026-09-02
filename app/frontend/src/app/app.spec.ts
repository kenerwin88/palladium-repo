import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { App } from './app';

describe('App', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [App],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();
  });

  it('shows the deployed environment returned by Flask', () => {
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();

    TestBed.inject(HttpTestingController).expectOne('/api/greeting').flush({
      environment: 'test',
      generated_at: '2026-09-02T12:00:00+00:00',
      message: 'Ready to ship.',
      version: '2026.09.02.1',
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Ready to ship.');
    expect(fixture.nativeElement.textContent).toContain('test · 2026.09.02.1');
  });
});
